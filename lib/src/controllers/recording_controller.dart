import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import '../models/display_info.dart';
import '../services/screen_selector_service.dart';
import '../services/screen_recorder_service.dart';
import '../services/cursor_overlay_service.dart';
import 'cursor_tracking_controller.dart';
import '../features/recording/domain/entities/screen_info.dart';

enum RecordingStatus {
  idle,
  recording,
  paused,
  saving,
  saved,
  error,
}

class RecordingState {
  final RecordingStatus status;
  final DisplayInfo? selectedDisplay;
  final ScreenInfo? selectedScreen;
  final String? statusMessage;
  final String? errorMessage;
  final bool isSystemAudioEnabled;

  const RecordingState({
    this.status = RecordingStatus.idle,
    this.selectedDisplay,
    this.selectedScreen,
    this.statusMessage,
    this.errorMessage,
    this.isSystemAudioEnabled = false,
  });

  RecordingState copyWith({
    RecordingStatus? status,
    DisplayInfo? selectedDisplay,
    ScreenInfo? selectedScreen,
    String? statusMessage,
    String? errorMessage,
    bool? isSystemAudioEnabled,
  }) {
    return RecordingState(
      status: status ?? this.status,
      selectedDisplay: selectedDisplay ?? this.selectedDisplay,
      selectedScreen: selectedScreen ?? this.selectedScreen,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      isSystemAudioEnabled: isSystemAudioEnabled ?? this.isSystemAudioEnabled,
    );
  }
}

final recordingControllerProvider =
    StateNotifierProvider<RecordingController, RecordingState>((ref) {
  return RecordingController(ref);
});

final availableScreensProvider = FutureProvider<List<DisplayInfo>>((ref) {
  return ScreenSelectorService.getDisplays();
});

final cursorPositionProvider = StateProvider<Offset?>((ref) => null);

class RecordingController extends StateNotifier<RecordingState> {
  final ScreenRecorderService _screenRecorderService;
  final CursorOverlayService _cursorOverlayService = CursorOverlayService();
  final List<void Function(ui.Image?)> _previewListeners = [];
  bool _isInitialized = false;
  BuildContext? _context;
  final Ref ref;
  Future<void>? _initializationFuture;

  RecordingController(this.ref) : 
    _screenRecorderService = ref.read(screenRecorderServiceProvider),
    super(const RecordingState()) {
    _initializationFuture = _initialize();
  }

  void updateContext(BuildContext context) {
    _context = context;
  }

  Future<void> ensureInitialized() async {
    if (_initializationFuture != null) {
      await _initializationFuture;
      _initializationFuture = null;
    }
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      await _screenRecorderService.initialize();
      await _cursorOverlayService.initialize();
      _isInitialized = true;
    } catch (e) {
      print('Error initializing recording controller: $e');
      rethrow;
    }
  }

  Future<List<DisplayInfo>> getDisplays() async {
    try {
      return await ScreenSelectorService.getDisplays();
    } catch (e) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'Failed to get displays: $e',
      );
      return [];
    }
  }

  void selectDisplay(DisplayInfo display) {
    debugPrint('Selecting display: ${display.name}');
    state = state.copyWith(
      selectedDisplay: display,
      selectedScreen: null, // Clear selected screen when selecting a display
    );
    
    // Start preview immediately after selecting display
    _startPreview();
    debugPrint('Started preview for display: ${display.name}');
  }

  void setScreen(ScreenInfo screen) {
    debugPrint('Setting screen: ${screen.windowTitle} (${screen.width}x${screen.height})');
    
    // Get window coordinates for windows
    if (screen.type == ScreenType.window) {
      final hwnd = screen.handle;
      final rect = calloc<RECT>();
      try {
        if (GetWindowRect(hwnd, rect) != 0) {
          final width = rect.ref.right - rect.ref.left;
          final height = rect.ref.bottom - rect.ref.top;
          debugPrint('Window coordinates: (${rect.ref.left},${rect.ref.top}) size: ${width}x$height');
          
          // Convert ScreenInfo to DisplayInfo with proper coordinates
          final display = DisplayInfo(
            id: screen.handle.toString(),
            name: screen.windowTitle ?? screen.name,
            width: width,
            height: height,
            x: rect.ref.left,
            y: rect.ref.top,
            isPrimary: false,
          );
          
          state = state.copyWith(
            selectedDisplay: display,
            selectedScreen: screen,
          );
          _startPreview();
        } else {
          final error = GetLastError();
          debugPrint('Failed to get window coordinates: $error');
        }
      } finally {
        calloc.free(rect);
      }
    } else {
      // Handle regular displays
      final display = DisplayInfo(
        id: screen.handle.toString(),
        name: screen.name,
        width: screen.width,
        height: screen.height,
        x: 0, // Regular displays start at 0,0
        y: 0,
        isPrimary: screen.isPrimary,
      );
      
      state = state.copyWith(
        selectedDisplay: display,
        selectedScreen: screen,
      );
      _startPreview();
    }
  }

  void _startPreview() {
    if (!_isInitialized) {
      debugPrint('Not initialized, initializing first...');
      _initialize().then((_) {
        debugPrint('Initialization complete, starting preview...');
        _startPreview();
      });
      return;
    }

    if (state.selectedDisplay != null) {
      final screen = state.selectedScreen;
      final display = state.selectedDisplay!;
      
      debugPrint('Starting preview for display: ${display.name}');
      
      // Stop any existing preview first
      _screenRecorderService.stopPreview();
      
      // Start new preview
      _screenRecorderService.startPreview(
        display,
        onFrame: (frame) {
          debugPrint('Received preview frame');
          _notifyPreviewListeners(frame);
        },
        isWindow: screen?.type == ScreenType.window,
      );
    } else {
      debugPrint('No display selected for preview');
    }
  }

  void addPreviewListener(void Function(ui.Image?) listener) {
    _previewListeners.add(listener);
  }

  void removePreviewListener(void Function(ui.Image?) listener) {
    _previewListeners.remove(listener);
  }

  void _notifyPreviewListeners(ui.Image? frame) {
    for (final listener in _previewListeners) {
      listener(frame);
    }
  }

  Future<void> startPreview() async {
    if (!_isInitialized) {
      await _initialize();
    }

    if (state.selectedDisplay == null) {
      final displays = await getDisplays();
      if (displays.isNotEmpty) {
        selectDisplay(displays.first);
      }
      return;
    }

    if (state.selectedDisplay != null) {
      await _screenRecorderService.startPreview(
        state.selectedDisplay!,
        onFrame: _notifyPreviewListeners,
      );
    }
  }

  void stopPreview() {
    _screenRecorderService.stopPreview();
  }

  Future<void> startRecording() async {
    if (state.selectedDisplay == null) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'No display selected',
      );
      return;
    }

    try {
      await _screenRecorderService.startRecording(
        state.selectedDisplay!,
        captureSystemAudio: state.isSystemAudioEnabled,
      );
      ref.read(cursorTrackingProvider.notifier).startTracking(state.selectedDisplay!);
      _cursorOverlayService.startRecording();
      state = state.copyWith(status: RecordingStatus.recording);
    } catch (e) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'Failed to start recording: $e',
      );
    }
  }

  Future<void> pauseRecording() async {
    try {
      await _screenRecorderService.pauseRecording();
      state = state.copyWith(status: RecordingStatus.paused);
    } catch (e) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'Failed to pause recording: $e',
      );
    }
  }

  Future<void> resumeRecording() async {
    try {
      await _screenRecorderService.resumeRecording();
      state = state.copyWith(status: RecordingStatus.recording);
    } catch (e) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'Failed to resume recording: $e',
      );
    }
  }

  Future<String?> stopRecording() async {
    try {
      final outputPath = await _screenRecorderService.stopRecording();
      if (_context != null) {
        ref.read(cursorTrackingProvider.notifier).stopTracking(outputPath, _context!);
      }
      _cursorOverlayService.stopRecording();
      state = state.copyWith(status: RecordingStatus.saved);
      return outputPath;
    } catch (e) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'Failed to stop recording: $e',
      );
      return null;
    }
  }

  void disableSystemAudio() {
    state = state.copyWith(
      isSystemAudioEnabled: false,
    );
  }

  void enableSystemAudio() {
    state = state.copyWith(
      isSystemAudioEnabled: true,
    );
  }

  void toggleSystemAudio() {
    state = state.copyWith(
      isSystemAudioEnabled: !state.isSystemAudioEnabled,
    );
  }

  @override
  void dispose() {
    _screenRecorderService.dispose();
    _cursorOverlayService.dispose();
    super.dispose();
  }
} 