import 'dart:ui' as ui;
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/display_info.dart';
import 'cursor_overlay_service.dart';
import 'ffmpeg_service.dart';
import 'preview_service.dart';
import 'camera_device_service.dart';

export 'ffmpeg_service.dart' show ffmpegServiceProvider;

// Win32 API constants that might be missing
const SRCCOPY = 0x00CC0020;
const BI_RGB = 0;
const DIB_RGB_COLORS = 0;
const ERROR_ACCESS_DENIED = 5;
const ERROR_INVALID_HANDLE = 6;
const ERROR_NOT_ENOUGH_MEMORY = 8;
const SM_CXSCREEN = 0;
const SM_CYSCREEN = 1;
const DWMWA_EXTENDED_FRAME_BOUNDS = 9;

class ScreenRecorderService {
  final Ref ref;
  DisplayInfo? _selectedDisplay;
  bool _isRecording = false;
  bool _isPaused = false;
  String? _outputPath;
  Function(ui.Image?)? _onPreviewFrame;
  Timer? _previewTimer;
  Timer? _cursorTimer;
  Process? _ffmpegProcess;
  final CursorOverlayService _cursorOverlay = CursorOverlayService();
  final FFmpegService _ffmpegService;
  static const _previewInterval = Duration(milliseconds: 100); // 10 FPS for preview
  static const _cursorInterval = Duration(milliseconds: 8); // ~120 FPS for cursor tracking

  ScreenRecorderService(this.ref, this._ffmpegService);

  Future<void> initialize() async {
    print('Initializing ScreenRecorderService...');
    
    try {
      // Check if we can access the screen
      final desktopWindow = GetDesktopWindow();
      if (desktopWindow == NULL) {
        final error = GetLastError();
        print('Failed to get desktop window handle. GetLastError: $error');
        throw Exception('Failed to initialize screen capture - cannot access desktop window');
      }
      print('Got desktop window handle successfully');

      // Try to get DC to verify permissions
      final testDC = GetDC(desktopWindow);
      if (testDC == NULL) {
        final error = GetLastError();
        print('Failed to get desktop DC during initialization. GetLastError: $error');
        if (error == ERROR_ACCESS_DENIED) {
          throw Exception('Screen capture permission denied. Please check app permissions.');
        }
        throw Exception('Failed to initialize screen capture');
      }
      print('Successfully got test DC');
      
      // Test creating a compatible DC
      final testCompatDC = CreateCompatibleDC(testDC);
      if (testCompatDC == NULL) {
        final error = GetLastError();
        print('Failed to create test compatible DC. GetLastError: $error');
        throw Exception('Failed to initialize screen capture - cannot create compatible DC');
      }
      print('Successfully created test compatible DC');
      
      // Clean up test DCs
      DeleteDC(testCompatDC);
      ReleaseDC(desktopWindow, testDC);
      print('Cleaned up test DCs');

      // Get screen dimensions to verify we can read screen metrics
      final screenWidth = GetSystemMetrics(SM_CXSCREEN);
      final screenHeight = GetSystemMetrics(SM_CYSCREEN);
      if (screenWidth == 0 || screenHeight == 0) {
        final error = GetLastError();
        print('Failed to get screen dimensions during initialization. GetLastError: $error');
        throw Exception('Failed to initialize screen capture - cannot get screen dimensions');
      }
      print('System screen dimensions: ${screenWidth}x$screenHeight');

      print('Screen capture initialization successful');
      await _cursorOverlay.initialize();
      print('Cursor overlay initialized');
    } catch (e) {
      print('Error during initialization: $e');
      rethrow;
    }
  }

  Future<void> startPreview(
    DisplayInfo display, {
    required Function(ui.Image?) onFrame,
    bool isWindow = false,
  }) async {
    // Get the preview service from the provider
    final previewService = ref.read(previewServiceProvider);
    
    // Connect the onFrame callback to the preview stream
    final subscription = previewService.previewStream.listen((frame) {
      onFrame(frame);
    });

    // Start the preview in the service
    previewService.startPreview(display);

    // Clean up the subscription when preview is stopped
    previewService.previewStream.listen(null, onDone: () {
      subscription.cancel();
    });
  }

  bool _isCursorInSelectedDisplay() {
    if (_selectedDisplay == null) return false;

    final cursorInfo = calloc<POINT>();
    try {
      if (GetCursorPos(cursorInfo) != 0) {
        final x = cursorInfo.ref.x;
        final y = cursorInfo.ref.y;
        
        return x >= _selectedDisplay!.x && 
               x < _selectedDisplay!.x + _selectedDisplay!.width &&
               y >= _selectedDisplay!.y && 
               y < _selectedDisplay!.y + _selectedDisplay!.height;
      }
      return false;
    } finally {
      calloc.free(cursorInfo);
    }
  }

  void _startCursorTracking() {
    _cursorTimer?.cancel();
    _cursorTimer = Timer.periodic(_cursorInterval, (timer) {
      if (_isCursorInSelectedDisplay()) {
        _cursorOverlay.updateCursor();
      }
    });
  }

  void stopPreview() {
    if (_previewTimer != null) {
      _previewTimer!.cancel();
    }
    if (_cursorTimer != null) {
      _cursorTimer!.cancel();
    }
    _previewTimer = null;
    _cursorTimer = null;
    _onPreviewFrame = null;
  }

  Future<void> _captureFrame({bool isPreview = false}) async {
    if (_selectedDisplay == null) return;

    int? hdcScreen;
    int? hdcMemory;
    int? hBitmap;
    final hwnd = int.tryParse(_selectedDisplay!.id) ?? 0;
    final isWindow = hwnd != 0;

    try {
      // Get the screen DC
      hdcScreen = GetDC(NULL);
      if (hdcScreen == NULL) {
        final error = GetLastError();
        if (error == ERROR_ACCESS_DENIED) {
          throw Exception('Screen capture permission denied');
        }
        throw Exception('Failed to get screen DC');
      }

      // Create a compatible DC
      hdcMemory = CreateCompatibleDC(hdcScreen);
      if (hdcMemory == NULL) {
        throw Exception('Failed to create compatible DC');
      }

      // Create a compatible bitmap
      final width = _selectedDisplay!.width;
      final height = _selectedDisplay!.height;
      
      if (width <= 0 || height <= 0) {
        throw Exception('Invalid display dimensions: ${width}x$height');
      }
      
      hBitmap = CreateCompatibleBitmap(hdcScreen, width, height);
      if (hBitmap == NULL) {
        throw Exception('Failed to create compatible bitmap');
      }

      // Select the bitmap into the compatible DC
      final oldBitmap = SelectObject(hdcMemory, hBitmap);
      if (oldBitmap == NULL) {
        throw Exception('Failed to select bitmap into DC');
      }

      if (isWindow) {
        // For window capture, use PrintWindow
        final result = PrintWindow(
          hwnd,
          hdcMemory,
          0, // PW_CLIENTONLY = 1, 0 for entire window
        );

        if (result == 0) {
          final error = GetLastError();
          throw Exception('Failed to capture window content');
        }
      } else {
        // For screen capture, use BitBlt
        final blitResult = BitBlt(
          hdcMemory,
          0,
          0,
          width,
          height,
          hdcScreen,
          _selectedDisplay!.x,
          _selectedDisplay!.y,
          SRCCOPY,
        );

        if (blitResult == 0) {
          final error = GetLastError();
          throw Exception('Failed to copy screen content');
        }
      }

      // Get the bitmap data
      final bmi = calloc<BITMAPINFO>();
      final pixels = calloc<Uint8>(width * height * 4);
      
      try {
        bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
        bmi.ref.bmiHeader.biWidth = width;
        bmi.ref.bmiHeader.biHeight = -height; // Negative for top-down bitmap
        bmi.ref.bmiHeader.biPlanes = 1;
        bmi.ref.bmiHeader.biBitCount = 32;
        bmi.ref.bmiHeader.biCompression = BI_RGB;

        final dibResult = GetDIBits(
          hdcMemory,
          hBitmap,
          0,
          height,
          pixels,
          bmi,
          DIB_RGB_COLORS,
        );

        if (dibResult == 0) {
          final error = GetLastError();
          throw Exception('Failed to get bitmap data');
        }

        // Create Flutter Image
        final completer = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          pixels.asTypedList(width * height * 4),
          width,
          height,
          ui.PixelFormat.bgra8888,
          (image) {
            completer.complete(image);
            if (_onPreviewFrame != null) {
              _onPreviewFrame!(image);
            }
          },
          targetWidth: isPreview ? width ~/ 2 : width, // Scale down for preview only
          targetHeight: isPreview ? height ~/ 2 : height,
        );
        await completer.future;
      } finally {
        calloc.free(bmi);
        calloc.free(pixels);
      }
    } catch (e) {
      throw Exception('Frame capture error: $e');
    } finally {
      if (hBitmap != null) DeleteObject(hBitmap);
      if (hdcMemory != null) DeleteDC(hdcMemory);
      if (hdcScreen != null) ReleaseDC(NULL, hdcScreen);
    }
  }

  Future<void> startRecording(DisplayInfo display, {bool captureSystemAudio = false}) async {
    if (_isRecording) return;

    // Get user's Documents folder path
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null) throw Exception('Could not find user profile directory');
    
    final recordingsDir = path.join(userProfile, 'Documents', 'OpenScreenStudio', 'Recordings');
    // Create directory if it doesn't exist
    await Directory(recordingsDir).create(recursive: true);
    
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    _outputPath = path.join(recordingsDir, 'recording_$timestamp.mp4');

    _selectedDisplay = display;
    _isRecording = true;
    _isPaused = false;

    print('Starting recording of display: ${display.width}x${display.height} at (${display.x},${display.y})');

    // Get selected camera if enabled
    final selectedCamera = ref.read(selectedCameraDeviceProvider);
    final isCameraEnabled = selectedCamera != null;

    // Get FFmpeg arguments from the service
    final ffmpegArgs = _ffmpegService.buildFFmpegArgs(
      outputPath: _outputPath!,
      region: {
        'x': display.x,
        'y': display.y,
        'width': display.width,
        'height': display.height,
      },
      showCursor: false, // Disable cursor capture since we handle it ourselves
      captureSystemAudio: captureSystemAudio,
      cameraDevice: selectedCamera, // Pass the camera device ID directly
    );

    try {
      _ffmpegProcess = await Process.start('ffmpeg', ffmpegArgs);
      
      // Log FFmpeg output for debugging
      _ffmpegProcess!.stdout.transform(systemEncoding.decoder).listen(print);
      _ffmpegProcess!.stderr.transform(systemEncoding.decoder).listen(print);
    } catch (e) {
      _isRecording = false;
      throw Exception('Failed to start FFmpeg: $e');
    }
  }

  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) return;
    _isPaused = true;
    // Keep preview running while paused
    if (_ffmpegProcess != null) {
      _ffmpegProcess!.stdin.write('p');
    }
  }

  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) return;
    _isPaused = false;
    if (_ffmpegProcess != null) {
      _ffmpegProcess!.stdin.write('p');
    }
  }

  Future<String> stopRecording() async {
    if (!_isRecording) throw Exception('Not recording');
    if (_outputPath == null) throw Exception('Output path not set');

    _isRecording = false;
    _isPaused = false;

    // Stop FFmpeg gracefully by sending 'q' command
    if (_ffmpegProcess != null) {
      _ffmpegProcess!.stdin.write('q');
      await _ffmpegProcess!.stdin.close();
      
      // Wait for FFmpeg to finish
      final exitCode = await _ffmpegProcess!.exitCode;
      _ffmpegProcess = null;
      
      if (exitCode != 0) {
        throw Exception('FFmpeg exited with code $exitCode');
      }
    }

    return _outputPath!;
  }

  void dispose() {
    stopPreview();
    if (_isRecording) {
      stopRecording();
    }
    _ffmpegProcess?.kill();
    _cursorOverlay.dispose();
  }
}

// Add provider
final screenRecorderServiceProvider = Provider((ref) {
  final ffmpegService = ref.watch(ffmpegServiceProvider);
  return ScreenRecorderService(ref, ffmpegService);
});