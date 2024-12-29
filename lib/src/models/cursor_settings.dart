import 'package:flutter/material.dart';

class CursorSettings {
  final double size;
  final double smoothness;
  final bool isVisible;
  final Color? tintColor;
  final double opacity;

  const CursorSettings({
    this.size = 1.0,
    this.smoothness = 0.5,
    this.isVisible = true,
    this.tintColor,
    this.opacity = 1.0,
  });

  CursorSettings copyWith({
    double? size,
    double? smoothness,
    bool? isVisible,
    Color? tintColor,
    double? opacity,
  }) {
    return CursorSettings(
      size: size ?? this.size,
      smoothness: smoothness ?? this.smoothness,
      isVisible: isVisible ?? this.isVisible,
      tintColor: tintColor ?? this.tintColor,
      opacity: opacity ?? this.opacity,
    );
  }
} 