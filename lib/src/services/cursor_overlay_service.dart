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

    using((Arena arena) {
      final point = arena<POINT>();
      if (GetCursorPos(point) != 0) {
        final cursorPos = Offset(
          point.ref.x.toDouble(),
          point.ref.y.toDouble(),
        );
        
        // Only update if position has changed
        if (cursorPos != _lastPosition) {
          _lastPosition = cursorPos;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _container.read(cursorPositionProvider.notifier).state = cursorPos;
          });
        }
      }
    });
  }

  void dispose() {
    _isInitialized = false;
    _isRecording = false;
    _lastPosition = null;
    _lastUpdate = null;
    _container.dispose();
  }
} 