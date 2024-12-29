import 'package:flutter_riverpod/flutter_riverpod.dart';

class AutoZoomState {
  final bool enabled;
  final double zoomLevel;
  final double smoothness;
  final double transitionDuration;

  const AutoZoomState({
    this.enabled = false,
    this.zoomLevel = 2.0,
    this.smoothness = 0.5,
    this.transitionDuration = 300,
  });

  AutoZoomState copyWith({
    bool? enabled,
    double? zoomLevel,
    double? smoothness,
    double? transitionDuration,
  }) {
    return AutoZoomState(
      enabled: enabled ?? this.enabled,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      smoothness: smoothness ?? this.smoothness,
      transitionDuration: transitionDuration ?? this.transitionDuration,
    );
  }
}

class AutoZoomNotifier extends StateNotifier<AutoZoomState> {
  AutoZoomNotifier() : super(const AutoZoomState());

  void toggleEnabled() {
    state = state.copyWith(enabled: !state.enabled);
  }

  void setZoomLevel(double level) {
    state = state.copyWith(zoomLevel: level.clamp(1.1, 4.0));
  }

  void setSmoothness(double smoothness) {
    state = state.copyWith(smoothness: smoothness.clamp(0.0, 1.0));
  }

  void setTransitionDuration(double duration) {
    state = state.copyWith(transitionDuration: duration.clamp(100, 1000));
  }
}

final autoZoomProvider = StateNotifierProvider<AutoZoomNotifier, AutoZoomState>((ref) {
  return AutoZoomNotifier();
}); 