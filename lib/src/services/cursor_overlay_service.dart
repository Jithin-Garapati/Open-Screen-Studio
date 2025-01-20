import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:win32/win32.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/recording_controller.dart';

class CursorOverlayService {
  final ProviderContainer _container;
  bool _isInitialized = false;
  bool _isRecording = false;
  Offset? _lastPosition;
  DateTime? _lastUpdate;
  static const updateThreshold = Duration(milliseconds: 16); // ~60fps

  CursorOverlayService() : _container = ProviderContainer();

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  void startRecording() {
    _isRecording = true;
  }

  void stopRecording() {
    _isRecording = false;
    _lastPosition = null;
    _lastUpdate = null;
  }

  void updateCursor() {
    if (!_isInitialized || !_isRecording) return;
    
    // Throttle updates
    final now = DateTime.now();
    if (_lastUpdate != null && now.difference(_lastUpdate!) < updateThreshold) {
      return;
    }
    _lastUpdate = now;

    final lpPoint = calloc<POINT>();
    try {
      if (GetCursorPos(lpPoint) != 0) {
        final cursorPos = Offset(
          lpPoint.ref.x.toDouble(),
          lpPoint.ref.y.toDouble(),
        );
        
        // Only update if position has changed
        if (_lastPosition == null || _lastPosition != cursorPos) {
          _lastPosition = cursorPos;
          
          // Get cursor type
          final cursorInfo = calloc<CURSORINFO>();
          cursorInfo.ref.cbSize = sizeOf<CURSORINFO>();
          
          try {
            if (GetCursorInfo(cursorInfo) != 0) {
              debugPrint('Cursor flags: ${cursorInfo.ref.flags}');
              final cursorHandle = (cursorInfo.ref.flags & 0x00000001 != 0)
                  ? cursorInfo.ref.hCursor
                  : LoadCursor(NULL, IDC_ARROW);
              debugPrint('Got cursor handle: $cursorHandle');
                  
              _container.read(recordingControllerProvider.notifier).updateCursor(
                cursorPos,
                cursorHandle,
              );
            }
          } finally {
            free(cursorInfo);
          }
        }
      }
    } finally {
      free(lpPoint);
    }
  }

  void dispose() {
    _isInitialized = false;
    _isRecording = false;
    _lastPosition = null;
    _lastUpdate = null;
    _container.dispose();
  }
} 