import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import '../../domain/entities/screen_info.dart';

class Win32ScreenRecorder {
  String? _outputPath;
  bool _isRecording = false;
  Timer? _recordingTimer;
  DateTime? _startTime;
  ScreenInfo? _selectedScreen;
  static const frameRate = 30;
  Timer? _frameTimer;
  List<String> _framePaths = [];

  Future<List<ScreenInfo>> getAvailableScreens() async {
    final screens = <ScreenInfo>[];
    
    // Get primary monitor
    final hMonitor = MonitorFromWindow(
      GetDesktopWindow(),
      MONITOR_FROM_FLAGS.MONITOR_DEFAULTTOPRIMARY,
    );

    final monitorInfo = calloc<MONITORINFO>();
    monitorInfo.ref.cbSize = sizeOf<MONITORINFO>();

    if (GetMonitorInfo(hMonitor, monitorInfo) != 0) {
      final rcMonitor = monitorInfo.ref.rcMonitor;
      final width = rcMonitor.right - rcMonitor.left;
      final height = rcMonitor.bottom - rcMonitor.top;
      final isPrimary = (monitorInfo.ref.dwFlags & MONITORINFOF_PRIMARY) != 0;

      screens.add(ScreenInfo(
        handle: hMonitor,
        name: 'Primary Display',
        width: width,
        height: height,
        isPrimary: isPrimary,
      ));
    }

    free(monitorInfo);
    return screens;
  }

  Future<void> startRecording({
    required ScreenInfo screen,
    String? customOutputPath,
  }) async {
    if (_isRecording) return;

    _selectedScreen = screen;
    _framePaths = [];
    
    // Setup output path
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final baseOutputPath = customOutputPath ?? path.join(
      (await getApplicationDocumentsDirectory()).path,
      'Open Screen Studio',
      'Recordings',
    );
    
    _outputPath = path.join(baseOutputPath, 'recording_$timestamp.mp4');
    
    // Create output directory
    Directory(path.dirname(_outputPath!)).createSync(recursive: true);

    _startTime = DateTime.now();
    _isRecording = true;

    // Start the recording timer for UI updates
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // This will be used to update recording duration in UI
    });

    // Start frame capture timer
    _frameTimer = Timer.periodic(const Duration(milliseconds: 1000 ~/ frameRate), (_) {
      _captureFrame();
    });
  }

  void _captureFrame() {
    if (!_isRecording || _selectedScreen == null) return;

    try {
      final monitorInfo = calloc<MONITORINFO>();
      monitorInfo.ref.cbSize = sizeOf<MONITORINFO>();

      if (GetMonitorInfo(_selectedScreen!.handle, monitorInfo) != 0) {
        final rcMonitor = monitorInfo.ref.rcMonitor;
        final width = rcMonitor.right - rcMonitor.left;
        final height = rcMonitor.bottom - rcMonitor.top;

        // Create DCs and bitmap
        final hdcScreen = GetDC(NULL);
        final hdcMemory = CreateCompatibleDC(hdcScreen);
        final hBitmap = CreateCompatibleBitmap(hdcScreen, width, height);
        SelectObject(hdcMemory, hBitmap);

        // Copy screen to bitmap
        BitBlt(
          hdcMemory,
          0,
          0,
          width,
          height,
          hdcScreen,
          rcMonitor.left,
          rcMonitor.top,
          ROP_CODE.SRCCOPY,
        );

        // Get bitmap info
        final bmi = calloc<BITMAPINFO>();
        bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
        bmi.ref.bmiHeader.biWidth = width;
        bmi.ref.bmiHeader.biHeight = -height; // Top-down
        bmi.ref.bmiHeader.biPlanes = 1;
        bmi.ref.bmiHeader.biBitCount = 32;
        bmi.ref.bmiHeader.biCompression = BI_COMPRESSION.BI_RGB;

        // Allocate buffer for pixel data
        final bufferSize = width * height * 4;
        final buffer = calloc<Uint8>(bufferSize);

        // Get bitmap bits
        GetDIBits(
          hdcMemory,
          hBitmap,
          0,
          height,
          buffer,
          bmi,
          DIB_USAGE.DIB_RGB_COLORS,
        );

        // Convert to image and save frame
        final frameBytes = buffer.asTypedList(bufferSize);
        final image = img.Image.fromBytes(
          width: width,
          height: height,
          bytes: frameBytes.buffer,
          numChannels: 4,
          order: img.ChannelOrder.bgra,
        );
        
        final framePath = path.join(
          Directory.systemTemp.path,
          'frame_${_framePaths.length}.png',
        );
        File(framePath).writeAsBytesSync(img.encodePng(image));
        _framePaths.add(framePath);

        // Cleanup
        free(buffer);
        free(bmi);
        DeleteObject(hBitmap);
        DeleteDC(hdcMemory);
        ReleaseDC(NULL, hdcScreen);
      }

      free(monitorInfo);
    } catch (e) {
      print('Error capturing frame: $e');
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecording || _outputPath == null) return null;

    _recordingTimer?.cancel();
    _frameTimer?.cancel();
    _recordingTimer = null;
    _frameTimer = null;
    _isRecording = false;

    try {
      if (_framePaths.isNotEmpty) {
        // For now, we'll just save the last frame as a screenshot
        final lastFramePath = _framePaths.last;
        final file = File(lastFramePath);
        if (await file.exists()) {
          await file.copy(_outputPath!);
        }

        // Cleanup
        for (final framePath in _framePaths) {
          final file = File(framePath);
          if (await file.exists()) {
            await file.delete();
          }
        }
        
        final duration = DateTime.now().difference(_startTime!);
        print('Stopped recording. Duration: ${duration.inSeconds} seconds');
        
        return _outputPath;
      }
      return null;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    } finally {
      _selectedScreen = null;
      _framePaths = [];
    }
  }

  bool get isRecording => _isRecording;

  Duration get recordingDuration {
    if (!_isRecording || _startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }

  String? get outputPath => _outputPath;
} 