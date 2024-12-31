import 'dart:async';
import 'dart:ui' as ui;
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:win32/win32.dart';
import '../models/display_info.dart';

final previewServiceProvider = Provider((ref) => PreviewService());

class PreviewService {
  Timer? _previewTimer;
  Timer? _audioTimer;
  final _previewStreamController = StreamController<ui.Image?>.broadcast();
  final _micLevelController = StreamController<double>.broadcast();
  final _systemAudioLevelController = StreamController<double>.broadcast();

  // Screen capture resources
  int? _hdcScreen;
  int? _hdcMemory;
  int? _hBitmap;
  Pointer<BITMAPINFO>? _bmi;
  Pointer<Uint8>? _pixels;
  bool _isCapturing = false;
  
  // Frame smoothing
  ui.Image? _lastFrame;
  DateTime? _lastCaptureTime;
  static const captureInterval = Duration(milliseconds: 100); // Capture every 100ms
  static const smoothUpdateInterval = Duration(milliseconds: 16); // Update UI at ~60fps

  // Audio monitoring handles
  int? _micHandle;
  int? _audioHandle;

  Stream<ui.Image?> get previewStream => _previewStreamController.stream;
  Stream<double> get micLevelStream => _micLevelController.stream;
  Stream<double> get systemAudioLevelStream => _systemAudioLevelController.stream;

  void startPreview(DisplayInfo display) async {
    debugPrint('Starting preview for display: ${display.name} (${display.width}x${display.height} at ${display.x},${display.y})');
    stopPreview();
    
    try {
      // Only treat it as a window if it's explicitly marked as one
      final isWindow = false;  // For now, treat all as displays until window capture is implemented
      debugPrint('Display type: ${isWindow ? "Window" : "Screen"}, ID: ${display.id}');

      _hdcScreen = GetDC(NULL);  // Always get the entire screen DC
      if (_hdcScreen == NULL) {
        final error = GetLastError();
        debugPrint('Failed to get screen DC: $error');
        throw Exception('Failed to get screen DC');
      }
      debugPrint('Got screen DC: $_hdcScreen');

      _hdcMemory = CreateCompatibleDC(_hdcScreen!);
      if (_hdcMemory == NULL) {
        final error = GetLastError();
        debugPrint('Failed to create compatible DC: $error');
        ReleaseDC(NULL, _hdcScreen!);
        throw Exception('Failed to create compatible DC');
      }
      debugPrint('Created memory DC: $_hdcMemory');

      _hBitmap = CreateCompatibleBitmap(_hdcScreen!, display.width, display.height);
      if (_hBitmap == NULL) {
        final error = GetLastError();
        debugPrint('Failed to create compatible bitmap: $error');
        DeleteDC(_hdcMemory!);
        ReleaseDC(NULL, _hdcScreen!);
        throw Exception('Failed to create compatible bitmap');
      }
      debugPrint('Created bitmap: $_hBitmap (${display.width}x${display.height})');

      final oldBitmap = SelectObject(_hdcMemory!, _hBitmap!);
      if (oldBitmap == NULL) {
        final error = GetLastError();
        debugPrint('Failed to select bitmap: $error');
        DeleteObject(_hBitmap!);
        DeleteDC(_hdcMemory!);
        ReleaseDC(NULL, _hdcScreen!);
        throw Exception('Failed to select bitmap into DC');
      }
      debugPrint('Selected bitmap into DC');

      _bmi = calloc<BITMAPINFO>();
      _bmi!.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
      _bmi!.ref.bmiHeader.biWidth = display.width;
      _bmi!.ref.bmiHeader.biHeight = -display.height;
      _bmi!.ref.bmiHeader.biPlanes = 1;
      _bmi!.ref.bmiHeader.biBitCount = 32;
      _bmi!.ref.bmiHeader.biCompression = BI_COMPRESSION.BI_RGB;
      debugPrint('Initialized BITMAPINFO: ${display.width}x${display.height}');

      _pixels = calloc<Uint8>(display.width * display.height * 4);
      debugPrint('Allocated pixel buffer: ${display.width * display.height * 4} bytes');
      
      _isCapturing = true;
      _startCapture(display);
      debugPrint('Started capture timer');
    } catch (e, stack) {
      debugPrint('Error starting preview: $e');
      debugPrint('Stack trace: $stack');
      _cleanupScreenCapture();
      rethrow;
    }
  }

  void _startCapture(DisplayInfo display) {
    if (!_isCapturing) {
      debugPrint('Not capturing, returning');
      return;
    }

    debugPrint('Starting capture timer for display: ${display.name}');
    _previewTimer?.cancel();
    
    _previewTimer = Timer.periodic(captureInterval, (timer) async {
      if (!_isCapturing) {
        debugPrint('Capture stopped, canceling timer');
        timer.cancel();
        return;
      }

      try {
        final blitResult = BitBlt(
          _hdcMemory!,
          0,
          0,
          display.width,
          display.height,
          _hdcScreen!,
          display.x,
          display.y,
          ROP_CODE.SRCCOPY,
        );

        if (blitResult == 0) {
          final error = GetLastError();
          debugPrint('BitBlt failed: $error');
          throw Exception('Failed to copy screen content');
        }
        debugPrint('Captured screen frame');

        final dibResult = GetDIBits(
          _hdcMemory!,
          _hBitmap!,
          0,
          display.height,
          _pixels!.cast(),
          _bmi!,
          DIB_USAGE.DIB_RGB_COLORS,
        );

        if (dibResult == 0) {
          final error = GetLastError();
          debugPrint('GetDIBits failed: $error');
          throw Exception('Failed to get bitmap data');
        }

        final completer = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          _pixels!.asTypedList(display.width * display.height * 4),
          display.width,
          display.height,
          ui.PixelFormat.bgra8888,
          (image) {
            debugPrint('Decoded frame: ${image.width}x${image.height}');
            _lastFrame = image;
            completer.complete(image);
            _previewStreamController.add(image);
          },
          targetWidth: display.width ~/ 2,
          targetHeight: display.height ~/ 2,
        );
        await completer.future;
      } catch (e, stack) {
        debugPrint('Error during capture: $e');
        debugPrint('Stack trace: $stack');
      }
    });
  }

  void _cleanupScreenCapture() {
    _isCapturing = false;
    _lastFrame = null;
    _lastCaptureTime = null;
    
    if (_pixels != null) {
      calloc.free(_pixels!);
      _pixels = null;
    }
    
    if (_bmi != null) {
      calloc.free(_bmi!);
      _bmi = null;
    }
    
    if (_hBitmap != null) {
      DeleteObject(_hBitmap!);
      _hBitmap = null;
    }
    
    if (_hdcMemory != null) {
      DeleteDC(_hdcMemory!);
      _hdcMemory = null;
    }
    
    if (_hdcScreen != null) {
      ReleaseDC(NULL, _hdcScreen!);
      _hdcScreen = null;
    }
  }

  void startAudioMonitoring() async {
    _audioTimer?.cancel();
    await _initializeAudioMonitoring();

    _audioTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      _updateAudioLevels();
    });
  }

  Future<void> _initializeAudioMonitoring() async {
    try {
      // For testing, just simulate audio levels
    } catch (e) {
      _cleanupAudioDevices();
    }
  }

  void _updateAudioLevels() {
    try {
      // Simulate audio levels for testing
      final now = DateTime.now().millisecondsSinceEpoch;
      final micLevel = ((now % 2000) / 2000.0).clamp(0.0, 1.0);
      final systemLevel = ((now % 1500) / 1500.0).clamp(0.0, 1.0);
      
      _micLevelController.add(micLevel);
      _systemAudioLevelController.add(systemLevel);
    } catch (e) {
      // Silently handle errors
    }
  }

  void _cleanupAudioDevices() {
    _micHandle = null;
    _audioHandle = null;
  }

  void stopPreview() {
    _previewTimer?.cancel();
    _cleanupScreenCapture();
    _previewStreamController.add(null);
  }

  void stopAudioMonitoring() async {
    _audioTimer?.cancel();
    _cleanupAudioDevices();
    _micLevelController.add(0.0);
    _systemAudioLevelController.add(0.0);
  }

  void dispose() {
    stopPreview();
    stopAudioMonitoring();
    _previewStreamController.close();
    _micLevelController.close();
    _systemAudioLevelController.close();
  }
} 