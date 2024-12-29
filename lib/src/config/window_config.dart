import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

enum WindowSizes {
  recording(Size(600, 56)),
  preview(Size(800, 600));

  final Size size;
  const WindowSizes(this.size);
}

Future<void> setupWindow({WindowSizes initialSize = WindowSizes.recording}) async {
  try {
    await windowManager.ensureInitialized();
    
    await windowManager.waitUntilReadyToShow();
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setSize(initialSize.size);
    await windowManager.setMinimumSize(initialSize.size);
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setHasShadow(true);
    await windowManager.setAlignment(Alignment.topRight);
    await windowManager.show();
  } catch (e) {
    debugPrint('Error setting up window: $e');
  }
}

Future<void> setWindowForRecording() async {
  try {
    await windowManager.ensureInitialized();
    await windowManager.setSize(WindowSizes.recording.size);
    await windowManager.setAlignment(Alignment.topRight);
    await windowManager.setResizable(false);
    await windowManager.setAlwaysOnTop(true);
  } catch (e) {
    debugPrint('Error setting window for recording: $e');
  }
}

Future<void> setWindowForPreview() async {
  try {
    await windowManager.ensureInitialized();
    await windowManager.setSize(WindowSizes.preview.size);
    await windowManager.setMinimumSize(WindowSizes.preview.size);
    await windowManager.setResizable(true);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.center();
  } catch (e) {
    debugPrint('Error setting window for preview: $e');
  }
} 