import 'package:flutter/material.dart';

class ZoomSettings {
  final double scale;
  final Offset target;
  final Duration duration;
  final Curve curve;
  final Duration transitionInDuration;  // Duration for zoom in transition
  final Duration transitionOutDuration; // Duration for zoom out transition
  final Curve transitionInCurve;        // Curve for zoom in transition
  final Curve transitionOutCurve;       // Curve for zoom out transition

  const ZoomSettings({
    this.scale = 1.5,
    this.target = const Offset(0.5, 0.5),  // Center by default
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeInOutCubic,
    this.transitionInDuration = const Duration(milliseconds: 300),
    this.transitionOutDuration = const Duration(milliseconds: 300),
    this.transitionInCurve = Curves.easeOutCubic,
    this.transitionOutCurve = Curves.easeInCubic,
  });

  ZoomSettings copyWith({
    double? scale,
    Offset? target,
    Duration? duration,
    Curve? curve,
    Duration? transitionInDuration,
    Duration? transitionOutDuration,
    Curve? transitionInCurve,
    Curve? transitionOutCurve,
  }) {
    return ZoomSettings(
      scale: scale ?? this.scale,
      target: target ?? this.target,
      duration: duration ?? this.duration,
      curve: curve ?? this.curve,
      transitionInDuration: transitionInDuration ?? this.transitionInDuration,
      transitionOutDuration: transitionOutDuration ?? this.transitionOutDuration,
      transitionInCurve: transitionInCurve ?? this.transitionInCurve,
      transitionOutCurve: transitionOutCurve ?? this.transitionOutCurve,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scale': scale,
      'targetX': target.dx,
      'targetY': target.dy,
      'durationMs': duration.inMilliseconds,
      'transitionInDurationMs': transitionInDuration.inMilliseconds,
      'transitionOutDurationMs': transitionOutDuration.inMilliseconds,
    };
  }

  factory ZoomSettings.fromJson(Map<String, dynamic> json) {
    return ZoomSettings(
      scale: json['scale'] as double? ?? 1.5,
      target: Offset(
        json['targetX'] as double? ?? 0.5,
        json['targetY'] as double? ?? 0.5,
      ),
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 500),
      transitionInDuration: Duration(milliseconds: json['transitionInDurationMs'] as int? ?? 300),
      transitionOutDuration: Duration(milliseconds: json['transitionOutDurationMs'] as int? ?? 300),
    );
  }
} 