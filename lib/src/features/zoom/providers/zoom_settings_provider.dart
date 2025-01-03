import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ZoomSettings {
  final double scale;
  final Offset translate;
  final Duration duration;
  final bool isAutoZoom;
  final Offset target;

  const ZoomSettings({
    this.scale = 1.0,
    this.translate = Offset.zero,
    this.duration = const Duration(milliseconds: 300),
    this.isAutoZoom = true,
    this.target = const Offset(0.5, 0.5),
  });

  ZoomSettings copyWith({
    double? scale,
    Offset? translate,
    Duration? duration,
    bool? isAutoZoom,
    Offset? target,
  }) {
    return ZoomSettings(
      scale: scale ?? this.scale,
      translate: translate ?? this.translate,
      duration: duration ?? this.duration,
      isAutoZoom: isAutoZoom ?? this.isAutoZoom,
      target: target ?? this.target,
    );
  }
}

class ZoomSettingsNotifier extends StateNotifier<ZoomSettings> {
  ZoomSettingsNotifier() : super(const ZoomSettings());

  void setScale(double scale) {
    state = state.copyWith(scale: scale);
  }

  void setTranslate(Offset translate) {
    state = state.copyWith(translate: translate);
  }

  void setDuration(Duration duration) {
    state = state.copyWith(duration: duration);
  }

  void setAutoZoom(bool enabled) {
    state = state.copyWith(isAutoZoom: enabled);
  }

  void setTarget(Offset target) {
    state = state.copyWith(target: target);
  }

  void reset() {
    state = const ZoomSettings();
  }
}

final zoomSettingsProvider = StateNotifierProvider<ZoomSettingsNotifier, ZoomSettings>((ref) {
  return ZoomSettingsNotifier();
}); 