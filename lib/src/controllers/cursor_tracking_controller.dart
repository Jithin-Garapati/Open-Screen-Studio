import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cursor_position.dart';
import '../services/cursor_tracker.dart';
import '../screens/video_preview_screen.dart';
import '../models/display_info.dart';

class CursorTrackingState {
  final List<CursorPosition> positions;
  final bool isTracking;
  final DateTime? startTime;

  const CursorTrackingState({
    this.positions = const [],
    this.isTracking = false,
    this.startTime,
  });

  CursorTrackingState copyWith({
    List<CursorPosition>? positions,
    bool? isTracking,
    DateTime? startTime,
  }) {
    return CursorTrackingState(
      positions: positions ?? this.positions,
      isTracking: isTracking ?? this.isTracking,
      startTime: startTime ?? this.startTime,
    );
  }
}

class CursorTrackingController extends StateNotifier<CursorTrackingState> {
  Timer? _tracker;

  CursorTrackingController() : super(const CursorTrackingState());

  void startTracking(DisplayInfo selectedDisplay) {
    CursorTracker.setSelectedDisplay(selectedDisplay);
    
    state = CursorTrackingState(
      positions: [],
      isTracking: true,
      startTime: DateTime.now(),
    );

    _tracker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _trackPosition();
    });
  }

  void stopTracking(String videoPath, BuildContext context) {
    _tracker?.cancel();
    state = state.copyWith(isTracking: false);

    // Navigate to preview screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPreviewScreen(
          videoPath: videoPath,
        ),
      ),
    );
  }

  void _trackPosition() {
    if (!state.isTracking || state.startTime == null) return;

    final cursorInfo = CursorTracker.getCurrentInfo();
    if (cursorInfo != null && cursorInfo.isInSelectedDisplay) {
      final timestamp = DateTime.now().difference(state.startTime!).inMilliseconds;
      state = state.copyWith(
        positions: [
          ...state.positions,
          CursorPosition(
            x: cursorInfo.position.dx,
            y: cursorInfo.position.dy,
            timestamp: timestamp,
            cursorType: cursorInfo.cursorType,
          ),
        ],
      );
    }
  }

  @override
  void dispose() {
    _tracker?.cancel();
    super.dispose();
  }
}

final cursorTrackingProvider =
    StateNotifierProvider<CursorTrackingController, CursorTrackingState>((ref) {
  return CursorTrackingController();
}); 