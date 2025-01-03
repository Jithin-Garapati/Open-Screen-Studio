import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

class CursorEvent {
  final Offset position;
  final int timestamp;
  final bool isClick;

  const CursorEvent({
    required this.position,
    required this.timestamp,
    this.isClick = false,
  });
}

class CursorEventsNotifier extends StateNotifier<List<CursorEvent>> {
  CursorEventsNotifier() : super([]);

  void addEvent(Offset position, int timestamp, {bool isClick = false}) {
    state = [...state, CursorEvent(position: position, timestamp: timestamp, isClick: isClick)];
  }

  void clear() {
    state = [];
  }

  Offset? getPositionForTime(int timestamp, int layerStartTime, int layerEndTime, {bool clicksOnly = false}) {
    // Find events within the layer timeframe
    final eventsInRange = state.where(
      (event) => event.timestamp >= layerStartTime && 
                 event.timestamp <= layerEndTime &&
                 (!clicksOnly || event.isClick)
    ).toList();

    if (eventsInRange.isEmpty) return null;

    // Find the closest event by timestamp
    eventsInRange.sort((a, b) => 
      (a.timestamp - timestamp).abs().compareTo((b.timestamp - timestamp).abs())
    );

    // If we're looking for clicks and have them, prioritize them
    if (clicksOnly) {
      final clicks = eventsInRange.where((e) => e.isClick).toList();
      if (clicks.isNotEmpty) {
        return clicks.first.position;
      }
    }

    return eventsInRange.first.position;
  }
}

final cursorEventsProvider = StateNotifierProvider<CursorEventsNotifier, List<CursorEvent>>(
  (ref) => CursorEventsNotifier(),
); 