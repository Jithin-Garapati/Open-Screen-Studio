import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/timeline_segment.dart';

class TimelineState {
  final double zoom;
  final List<TimelineSegment> segments;
  final Duration clipStartTime;
  final Duration clipEndTime;
  final bool isPlaying;
  final Duration currentTime;
  final Duration totalDuration;
  final List<TimelineState> undoStack;
  final List<TimelineState> redoStack;
  final bool snapEnabled;
  final double snapThreshold;
  final Set<TimelineSegment> selectedSegments;

  TimelineState({
    this.zoom = 1.0,
    this.segments = const [],
    this.clipStartTime = Duration.zero,
    this.clipEndTime = Duration.zero,
    this.isPlaying = false,
    this.currentTime = Duration.zero,
    this.totalDuration = Duration.zero,
    this.undoStack = const [],
    this.redoStack = const [],
    this.snapEnabled = true,
    this.snapThreshold = 10.0,
    this.selectedSegments = const {},
  });

  TimelineState copyWith({
    double? zoom,
    List<TimelineSegment>? segments,
    Duration? clipStartTime,
    Duration? clipEndTime,
    bool? isPlaying,
    Duration? currentTime,
    Duration? totalDuration,
    List<TimelineState>? undoStack,
    List<TimelineState>? redoStack,
    bool? snapEnabled,
    double? snapThreshold,
    Set<TimelineSegment>? selectedSegments,
  }) {
    return TimelineState(
      zoom: zoom ?? this.zoom,
      segments: segments ?? this.segments,
      clipStartTime: clipStartTime ?? this.clipStartTime,
      clipEndTime: clipEndTime ?? this.clipEndTime,
      isPlaying: isPlaying ?? this.isPlaying,
      currentTime: currentTime ?? this.currentTime,
      totalDuration: totalDuration ?? this.totalDuration,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      snapEnabled: snapEnabled ?? this.snapEnabled,
      snapThreshold: snapThreshold ?? this.snapThreshold,
      selectedSegments: selectedSegments ?? this.selectedSegments,
    );
  }

  TimelineState withoutHistory() {
    return TimelineState(
      zoom: zoom,
      segments: segments,
      clipStartTime: clipStartTime,
      clipEndTime: clipEndTime,
      isPlaying: isPlaying,
      currentTime: currentTime,
      totalDuration: totalDuration,
      snapEnabled: snapEnabled,
      snapThreshold: snapThreshold,
      selectedSegments: selectedSegments,
    );
  }

  int findNearestSnapPoint(int timeMs, double pixelsPerSecond) {
    if (!snapEnabled) return timeMs;

    // Snap points: segment boundaries and whole seconds
    final snapPoints = <int>{
      ...segments.map((s) => s.startTime),
      ...segments.map((s) => s.endTime),
      ..._generateSecondSnapPoints(),
    };

    // Find nearest snap point within threshold
    final thresholdMs = (snapThreshold / pixelsPerSecond * 1000).round();
    int nearestPoint = timeMs;
    int minDistance = thresholdMs;

    for (final point in snapPoints) {
      final distance = (point - timeMs).abs();
      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = point;
      }
    }

    return nearestPoint;
  }

  Set<int> _generateSecondSnapPoints() {
    final points = <int>{};
    for (var i = 0; i <= totalDuration.inSeconds; i++) {
      points.add(i * 1000); // Convert seconds to milliseconds
    }
    return points;
  }
}

class TimelineNotifier extends StateNotifier<TimelineState> {
  TimelineNotifier() : super(TimelineState());

  void _pushUndo() {
    final currentState = state.withoutHistory();
    state = state.copyWith(
      undoStack: [...state.undoStack, currentState],
      redoStack: [], // Clear redo stack when new action is performed
    );
  }

  bool get canUndo => state.undoStack.isNotEmpty;
  bool get canRedo => state.redoStack.isNotEmpty;

  void undo() {
    if (!canUndo) return;
    
    final undoStack = [...state.undoStack];
    final previousState = undoStack.removeLast();
    
    state = previousState.copyWith(
      undoStack: undoStack,
      redoStack: [...state.redoStack, state.withoutHistory()],
    );
  }

  void redo() {
    if (!canRedo) return;
    
    final redoStack = [...state.redoStack];
    final nextState = redoStack.removeLast();
    
    state = nextState.copyWith(
      undoStack: [...state.undoStack, state.withoutHistory()],
      redoStack: redoStack,
    );
  }

  void setZoom(double zoom) {
    _pushUndo();
    state = state.copyWith(zoom: zoom.clamp(0.1, 10.0));
  }

  void addSegment(TimelineSegment segment) {
    if (!segment.isValid) return;
    
    // Check for overlaps
    final hasOverlap = state.segments.any((s) => s.overlaps(segment));
    if (hasOverlap) return;

    _pushUndo();
    final segments = [...state.segments, segment];
    segments.sort((a, b) => a.startTime.compareTo(b.startTime));
    state = state.copyWith(segments: segments);
  }

  void removeSegment(TimelineSegment segment) {
    _pushUndo();
    final segments = [...state.segments];
    segments.remove(segment);
    state = state.copyWith(segments: segments);
  }

  void updateSegment(TimelineSegment oldSegment, TimelineSegment newSegment) {
    if (!newSegment.isValid) return;

    // Check for overlaps, excluding the segment being updated
    final hasOverlap = state.segments
        .where((s) => s != oldSegment)
        .any((s) => s.overlaps(newSegment));
    if (hasOverlap) return;

    _pushUndo();
    final segments = [...state.segments];
    final index = segments.indexOf(oldSegment);
    if (index != -1) {
      segments[index] = newSegment;
      segments.sort((a, b) => a.startTime.compareTo(b.startTime));
      state = state.copyWith(segments: segments);
    }
  }

  void setClipRange(Duration startTime, Duration endTime) {
    if (startTime <= endTime && startTime >= Duration.zero && endTime <= state.totalDuration) {
      _pushUndo();
      state = state.copyWith(
        clipStartTime: startTime,
        clipEndTime: endTime,
      );
    }
  }

  void setCurrentTime(Duration time) {
    if (time >= Duration.zero && time <= state.totalDuration) {
      state = state.copyWith(currentTime: time);
    }
  }

  void setTotalDuration(Duration duration) {
    _pushUndo();
    state = state.copyWith(
      totalDuration: duration,
      clipEndTime: duration,
    );
  }

  void setPlaying(bool isPlaying) {
    state = state.copyWith(isPlaying: isPlaying);
  }

  void clear() {
    _pushUndo();
    state = TimelineState(totalDuration: state.totalDuration);
  }

  void splitSegmentAtTime(int timeMs) {
    final segmentToSplit = state.segments.firstWhere(
      (segment) => segment.contains(timeMs),
      orElse: () => TimelineSegment(startTime: timeMs, endTime: timeMs),
    );

    if (segmentToSplit.isValid) {
      _pushUndo();
      
      // Create two new segments
      final firstHalf = segmentToSplit.copyWith(
        endTime: timeMs,
      );
      
      final secondHalf = segmentToSplit.copyWith(
        startTime: timeMs,
      );

      // Replace old segment with two new ones
      final segments = [...state.segments];
      final index = segments.indexOf(segmentToSplit);
      segments
        ..removeAt(index)
        ..insertAll(index, [firstHalf, secondHalf]);
      
      segments.sort((a, b) => a.startTime.compareTo(b.startTime));
      state = state.copyWith(segments: segments);
    }
  }

  void mergeSegments(TimelineSegment first, TimelineSegment second) {
    if (first.endTime != second.startTime || first.type != second.type) return;

    _pushUndo();
    final merged = first.copyWith(endTime: second.endTime);
    final segments = [...state.segments]
      ..remove(first)
      ..remove(second)
      ..add(merged);
    
    segments.sort((a, b) => a.startTime.compareTo(b.startTime));
    state = state.copyWith(segments: segments);
  }

  void duplicateSegment(TimelineSegment segment) {
    _pushUndo();
    final duration = segment.endTime - segment.startTime;
    final newSegment = segment.copyWith(
      startTime: segment.endTime,
      endTime: segment.endTime + duration,
    );
    
    if (newSegment.endTime <= state.totalDuration.inMilliseconds) {
      final segments = [...state.segments, newSegment];
      segments.sort((a, b) => a.startTime.compareTo(b.startTime));
      state = state.copyWith(segments: segments);
    }
  }

  void setSnapEnabled(bool enabled) {
    state = state.copyWith(snapEnabled: enabled);
  }

  void setSnapThreshold(double threshold) {
    state = state.copyWith(snapThreshold: threshold.clamp(1.0, 50.0));
  }

  void updateSegmentWithSnapping(TimelineSegment oldSegment, TimelineSegment newSegment, double pixelsPerSecond) {
    if (!newSegment.isValid) return;

    final snappedStartTime = state.findNearestSnapPoint(newSegment.startTime, pixelsPerSecond);
    final snappedEndTime = state.findNearestSnapPoint(newSegment.endTime, pixelsPerSecond);

    final snappedSegment = newSegment.copyWith(
      startTime: snappedStartTime,
      endTime: snappedEndTime,
    );

    if (snappedSegment.isValid) {
      updateSegment(oldSegment, snappedSegment);
    }
  }

  void selectSegment(TimelineSegment segment, {bool addToSelection = false}) {
    if (addToSelection) {
      final newSelection = {...state.selectedSegments};
      if (newSelection.contains(segment)) {
        newSelection.remove(segment);
      } else {
        newSelection.add(segment);
      }
      state = state.copyWith(selectedSegments: newSelection);
    } else {
      state = state.copyWith(selectedSegments: {segment});
    }
  }

  void clearSelection() {
    state = state.copyWith(selectedSegments: {});
  }

  void deleteSelectedSegments() {
    if (state.selectedSegments.isEmpty) return;
    _pushUndo();
    
    final segments = [...state.segments]
      ..removeWhere(state.selectedSegments.contains);
    
    state = state.copyWith(
      segments: segments,
      selectedSegments: {},
    );
  }

  void duplicateSelectedSegments() {
    if (state.selectedSegments.isEmpty) return;
    _pushUndo();

    final newSegments = [...state.segments];
    final duplicates = <TimelineSegment>[];

    for (final segment in state.selectedSegments) {
      final duration = segment.endTime - segment.startTime;
      final newSegment = segment.copyWith(
        startTime: segment.endTime,
        endTime: segment.endTime + duration,
      );
      
      if (newSegment.endTime <= state.totalDuration.inMilliseconds &&
          !newSegments.any((s) => s.overlaps(newSegment))) {
        duplicates.add(newSegment);
      }
    }

    newSegments.addAll(duplicates);
    newSegments.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    state = state.copyWith(
      segments: newSegments,
      selectedSegments: Set.from(duplicates),
    );
  }

  void groupSelectedSegments() {
    if (state.selectedSegments.length < 2) return;
    _pushUndo();

    final selected = state.selectedSegments.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // Create a group segment that spans all selected segments
    final groupSegment = TimelineSegment(
      startTime: selected.first.startTime,
      endTime: selected.last.endTime,
      type: SegmentType.normal,
      properties: {
        'isGroup': true,
        'children': selected.map((s) => s.toJson()).toList(),
      },
    );

    final segments = [...state.segments]
      ..removeWhere(state.selectedSegments.contains)
      ..add(groupSegment);
    
    segments.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    state = state.copyWith(
      segments: segments,
      selectedSegments: {groupSegment},
    );
  }

  void ungroupSelectedSegments() {
    if (state.selectedSegments.isEmpty) return;
    _pushUndo();

    final segments = [...state.segments];
    final newSegments = <TimelineSegment>[];

    for (final segment in state.selectedSegments) {
      if (segment.properties['isGroup'] == true) {
        final children = (segment.properties['children'] as List)
          .map((json) => TimelineSegment.fromJson(json as Map<String, dynamic>));
        newSegments.addAll(children);
        segments.remove(segment);
      }
    }

    segments.addAll(newSegments);
    segments.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    state = state.copyWith(
      segments: segments,
      selectedSegments: Set.from(newSegments),
    );
  }
}

final timelineProvider = StateNotifierProvider<TimelineNotifier, TimelineState>((ref) {
  return TimelineNotifier();
}); 