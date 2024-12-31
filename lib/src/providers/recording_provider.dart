import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cursor_position.dart';
import '../screens/video_editor_screen.dart';
import '../services/cursor_tracker.dart';

class RecordingState {
  final String? videoPath;
  final List<CursorPosition> cursorPositions;
  final bool isRecording;
  final DateTime? recordingStartTime;

  const RecordingState({
    this.videoPath,
    this.cursorPositions = const [],
    this.isRecording = false,
    this.recordingStartTime,
  });

  RecordingState copyWith({
    String? videoPath,
    List<CursorPosition>? cursorPositions,
    bool? isRecording,
    DateTime? recordingStartTime,
  }) {
    return RecordingState(
      videoPath: videoPath ?? this.videoPath,
      cursorPositions: cursorPositions ?? this.cursorPositions,
      isRecording: isRecording ?? this.isRecording,
      recordingStartTime: recordingStartTime ?? this.recordingStartTime,
    );
  }
}

class RecordingNotifier extends StateNotifier<RecordingState> {
  RecordingNotifier() : super(const RecordingState());
  Timer? _cursorTracker;

  void startRecording() {
    final startTime = DateTime.now();
    state = state.copyWith(
      isRecording: true,
      cursorPositions: [],
      recordingStartTime: startTime,
    );

    // Start tracking cursor position
    _cursorTracker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _trackPosition();
    });
  }

  void stopRecording(String videoPath, BuildContext context) {
    _cursorTracker?.cancel();
    state = state.copyWith(
      isRecording: false,
      videoPath: videoPath,
    );

    // Navigate to preview screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoEditorScreen(videoPath: videoPath),
      ),
    );
  }

  void _trackPosition() {
    if (!state.isRecording) return;
    
    final cursorInfo = CursorTracker.getCurrentInfo();
    if (cursorInfo != null) {
      final timestamp = DateTime.now().difference(state.recordingStartTime!).inMilliseconds;
      addCursorPosition(CursorPosition(
        x: cursorInfo.position.dx,
        y: cursorInfo.position.dy,
        timestamp: timestamp,
        cursorType: cursorInfo.cursorType,
      ));
    }
  }

  void addCursorPosition(CursorPosition position) {
    state = state.copyWith(
      cursorPositions: [...state.cursorPositions, position],
    );
  }
}

final recordingProvider = StateNotifierProvider<RecordingNotifier, RecordingState>(
  (ref) => RecordingNotifier(),
); 