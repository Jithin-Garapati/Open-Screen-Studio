import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../models/background_settings.dart';

class BackgroundSettingsNotifier extends StateNotifier<BackgroundSettings> {
  BackgroundSettingsNotifier() : super(const BackgroundSettings(
    type: BackgroundType.color,
    color: Color(0xFFFFB74D),
  ));

  void setType(BackgroundType type) {
    state = state.copyWith(type: type);
  }

  void setColor(Color color) {
    state = state.copyWith(color: color);
  }

  void setCornerRadius(double radius) {
    state = state.copyWith(cornerRadius: radius);
  }

  void setPadding(double padding) {
    state = state.copyWith(padding: padding);
  }

  void setScale(double scale) {
    state = state.copyWith(scale: scale);
  }

  void setMaintainAspectRatio(bool maintain) {
    state = state.copyWith(maintainAspectRatio: maintain);
  }
}

final backgroundSettingsProvider = StateNotifierProvider<BackgroundSettingsNotifier, BackgroundSettings>((ref) {
  return BackgroundSettingsNotifier();
}); 