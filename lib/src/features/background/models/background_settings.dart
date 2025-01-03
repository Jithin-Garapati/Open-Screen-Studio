import 'package:flutter/material.dart';

enum BackgroundType {
  color,
  gradient,
  image,
  none
}

class BackgroundSettings {
  final BackgroundType type;
  final Color? color;
  final double cornerRadius;
  final double padding;
  final double scale;
  final bool maintainAspectRatio;

  const BackgroundSettings({
    this.type = BackgroundType.none,
    this.color,
    this.cornerRadius = 12.0,
    this.padding = 32.0,
    this.scale = 0.9,
    this.maintainAspectRatio = true,
  });

  BackgroundSettings copyWith({
    BackgroundType? type,
    Color? color,
    double? cornerRadius,
    double? padding,
    double? scale,
    bool? maintainAspectRatio,
  }) {
    return BackgroundSettings(
      type: type ?? this.type,
      color: color ?? this.color,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      padding: padding ?? this.padding,
      scale: scale ?? this.scale,
      maintainAspectRatio: maintainAspectRatio ?? this.maintainAspectRatio,
    );
  }
} 