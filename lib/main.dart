import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/config/window_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await windowManager.ensureInitialized();
  await setupWindow(initialSize: WindowSizes.recording);

  // Initialize media_kit
  MediaKit.ensureInitialized();

  runApp(const ProviderScope(child: OpenScreenStudio()));
} 