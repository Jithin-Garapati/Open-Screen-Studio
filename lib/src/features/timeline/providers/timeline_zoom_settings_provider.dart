import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TimelineZoomSettings {
  final String layerId;
  final double scale;
  final bool isAutoZoom;
  final Offset target;

  const TimelineZoomSettings({
    required this.layerId,
    this.scale = 2.0,
    this.isAutoZoom = true,
    this.target = const Offset(0.5, 0.5),
  });

  TimelineZoomSettings copyWith({
    String? layerId,
    double? scale,
    bool? isAutoZoom,
    Offset? target,
  }) {
    return TimelineZoomSettings(
      layerId: layerId ?? this.layerId,
      scale: scale ?? this.scale,
      isAutoZoom: isAutoZoom ?? this.isAutoZoom,
      target: target ?? this.target,
    );
  }
}

class TimelineZoomSettingsNotifier extends StateNotifier<Map<String, TimelineZoomSettings>> {
  TimelineZoomSettingsNotifier() : super({});

  void setSettings(String layerId, TimelineZoomSettings settings) {
    state = {...state, layerId: settings};
  }

  void updateSettings(String layerId, {
    double? scale,
    bool? isAutoZoom,
    Offset? target,
  }) {
    if (!state.containsKey(layerId)) {
      state = {
        ...state,
        layerId: TimelineZoomSettings(
          layerId: layerId,
          scale: scale ?? 2.0,
          isAutoZoom: isAutoZoom ?? true,
          target: target ?? const Offset(0.5, 0.5),
        ),
      };
    } else {
      state = {
        ...state,
        layerId: state[layerId]!.copyWith(
          scale: scale,
          isAutoZoom: isAutoZoom,
          target: target,
        ),
      };
    }
  }

  void removeSettings(String layerId) {
    final newState = Map<String, TimelineZoomSettings>.from(state);
    newState.remove(layerId);
    state = newState;
  }
}

final timelineZoomSettingsProvider = StateNotifierProvider<TimelineZoomSettingsNotifier, Map<String, TimelineZoomSettings>>((ref) {
  return TimelineZoomSettingsNotifier();
}); 