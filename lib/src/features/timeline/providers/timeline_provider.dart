import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/timeline_segment.dart';

class TimelineState {
  final List<TimelineSegment> segments;
  final List<TimelineSegment> selectedSegments;
  final bool isPlaying;
  final double zoom;
  final bool snapEnabled;
  final Duration currentTime;

  const TimelineState({
    this.segments = const [],
    this.selectedSegments = const [],
    this.isPlaying = false,
    this.zoom = 1.0,
    this.snapEnabled = true,
    this.currentTime = Duration.zero,
  });

  TimelineState copyWith({
    List<TimelineSegment>? segments,
    List<TimelineSegment>? selectedSegments,
    bool? isPlaying,
    double? zoom,
    bool? snapEnabled,
    Duration? currentTime,
  }) {
    return TimelineState(
      segments: segments ?? this.segments,
      selectedSegments: selectedSegments ?? this.selectedSegments,
      isPlaying: isPlaying ?? this.isPlaying,
      zoom: zoom ?? this.zoom,
      snapEnabled: snapEnabled ?? this.snapEnabled,
      currentTime: currentTime ?? this.currentTime,
    );
  }
}

class TimelineNotifier extends StateNotifier<TimelineState> {
  TimelineNotifier() : super(const TimelineState());

  void setPlaying(bool playing) {
    state = state.copyWith(isPlaying: playing);
  }

  void setZoom(double zoom) {
    state = state.copyWith(zoom: zoom.clamp(0.1, 5.0));
  }

  void setSnapEnabled(bool enabled) {
    state = state.copyWith(snapEnabled: enabled);
  }

  void addSegment(TimelineSegment segment) {
    state = state.copyWith(
      segments: [...state.segments, segment],
    );
  }

  void updateSegment(TimelineSegment oldSegment, TimelineSegment newSegment) {
    final index = state.segments.indexOf(oldSegment);
    if (index != -1) {
      final newSegments = List<TimelineSegment>.from(state.segments);
      newSegments[index] = newSegment;
      state = state.copyWith(segments: newSegments);
    }
  }

  void removeSegment(TimelineSegment segment) {
    state = state.copyWith(
      segments: state.segments.where((s) => s != segment).toList(),
      selectedSegments: state.selectedSegments.where((s) => s != segment).toList(),
    );
  }

  void selectSegment(TimelineSegment segment, {bool addToSelection = false}) {
    if (addToSelection) {
      state = state.copyWith(
        selectedSegments: [...state.selectedSegments, segment],
      );
    } else {
      state = state.copyWith(
        selectedSegments: [segment],
      );
    }
  }

  void clearSelection() {
    state = state.copyWith(selectedSegments: []);
  }

  void deleteSelectedSegments() {
    state = state.copyWith(
      segments: state.segments.where((s) => !state.selectedSegments.contains(s)).toList(),
      selectedSegments: [],
    );
  }

  void splitSegmentAtTime(int timestamp) {
    // Implementation for splitting segment at timestamp
  }

  void undo() {
    // Implementation for undo
  }

  void redo() {
    // Implementation for redo
  }
}

final timelineProvider = StateNotifierProvider<TimelineNotifier, TimelineState>((ref) {
  return TimelineNotifier();
}); 