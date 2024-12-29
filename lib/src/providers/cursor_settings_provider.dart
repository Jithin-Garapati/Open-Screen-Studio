import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cursor_settings.dart';

class CursorSettingsNotifier extends StateNotifier<CursorSettings> {
  CursorSettingsNotifier() : super(const CursorSettings());

  void updateSize(double size) {
    state = state.copyWith(size: size);
  }

  void updateSmoothness(double smoothness) {
    state = state.copyWith(smoothness: smoothness);
  }

  void toggleVisibility() {
    state = state.copyWith(isVisible: !state.isVisible);
  }

  void updateTintColor(Color? color) {
    state = state.copyWith(tintColor: color);
  }

  void updateOpacity(double opacity) {
    state = state.copyWith(opacity: opacity);
  }

  void reset() {
    state = const CursorSettings();
  }
}

final cursorSettingsProvider = StateNotifierProvider<CursorSettingsNotifier, CursorSettings>((ref) {
  return CursorSettingsNotifier();
}); 