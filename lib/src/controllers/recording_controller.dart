import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;
import 'package:window_manager/window_manager.dart';
import '../models/display_info.dart';
import '../services/screen_selector_service.dart';
import '../services/screen_recorder_service.dart';
import '../services/cursor_overlay_service.dart';
import '../config/window_config.dart';
import 'cursor_tracking_controller.dart';
import '../features/recording/domain/entities/screen_info.dart';
import '../providers/providers.dart';
import '../services/audio_device_service.dart';

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

  RecordingController(this.ref) : 
    _screenRecorderService = ref.read(screenRecorderServiceProvider),
    super(const RecordingState()) {
    _initialize();
  }

  void updateContext(BuildContext context) {
    _context = context;
  }

  Future<void> _initialize() async {
    await _screenRecorderService.initialize();
    await _cursorOverlayService.initialize();
    _isInitialized = true;
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
    state = state.copyWith(selectedDisplay: display);
    _startPreview();
  }

  void setScreen(ScreenInfo screen) {
    // Convert ScreenInfo to DisplayInfo for backward compatibility
    final display = DisplayInfo(
      id: screen.handle.toString(),
      name: screen.name,
      width: screen.width,
      height: screen.height,
      x: 0, // These values will be set correctly when starting preview/recording
      y: 0,
      isPrimary: screen.isPrimary,
    );
    
    state = state.copyWith(
      selectedDisplay: display,
      selectedScreen: screen,
    );
    _startPreview();
  }

  void _startPreview() {
    if (!_isInitialized) {
      _initialize().then((_) => _startPreview());
      return;
    }

    if (state.selectedDisplay != null) {
      _screenRecorderService.startPreview(
        state.selectedDisplay!,
        onFrame: _notifyPreviewListeners,
      );
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
      if (_context != null && outputPath != null) {
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