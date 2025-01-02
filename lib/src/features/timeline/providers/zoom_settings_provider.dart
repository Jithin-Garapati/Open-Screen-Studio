import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/zoom_settings.dart';

class ZoomSettingsNotifier extends StateNotifier<Map<String, ZoomSettings>> {
  ZoomSettingsNotifier() : super({});

  void updateSettings(String layerId, ZoomSettings settings) {
    state = {...state, layerId: settings};
  }

  void removeSettings(String layerId) {
    final newState = Map<String, ZoomSettings>.from(state);
    newState.remove(layerId);
    state = newState;
  }

  ZoomSettings? getSettings(String layerId) {
    return state[layerId];
  }
}

final zoomSettingsProvider = StateNotifierProvider<ZoomSettingsNotifier, Map<String, ZoomSettings>>((ref) {
  return ZoomSettingsNotifier();
});

final activeZoomLayerProvider = StateProvider<String?>((ref) => null); 