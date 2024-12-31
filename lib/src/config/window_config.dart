import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

enum WindowSizes {
  recording(Size(680, 580)),
  recordingMinimized(Size(400, 100)),
  editor(Size(1280, 720)),
  preview(Size(1280, 720));

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
    
    // Center the window on startup
    if (initialSize == WindowSizes.recording) {
      await windowManager.center();
    } else {
      await windowManager.setAlignment(Alignment.topRight);
    }
    
    await windowManager.show();
  } catch (e) {
    debugPrint('Error setting up window: $e');
  }
}

Future<void> setWindowForRecording() async {
  try {
    await windowManager.ensureInitialized();
    
    // First set the size
    final windowSize = WindowSizes.recordingMinimized.size;
    await windowManager.setSize(windowSize);
    await windowManager.setMinimumSize(windowSize);
    
    // Position window on the right side
    await windowManager.setAlignment(Alignment.centerRight);
    
    await windowManager.setResizable(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setMovable(true);
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

Future<Future<void> Function()> temporarilyExpandWindowHeight(double additionalHeight) async {
  try {
    final currentSize = await windowManager.getSize();
    final currentPos = await windowManager.getPosition();
    
    // Expand window downward
    await windowManager.setSize(Size(currentSize.width, currentSize.height + additionalHeight));
    
    // Return the cleanup function
    return () async {
      await windowManager.setSize(currentSize);
      await windowManager.setPosition(currentPos);
    };
  } catch (e) {
    debugPrint('Error adjusting window for dropdown: $e');
    // Return a no-op cleanup function
    return () async {};
  }
} 