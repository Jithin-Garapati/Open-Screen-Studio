import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/cursor_tracking_controller.dart';
import '../screens/video_editor_screen.dart';
import '../models/display_info.dart';

class RecordingNavigationService {
  static void startRecording(WidgetRef ref, DisplayInfo display) {
    ref.read(cursorTrackingProvider.notifier).startTracking(display);
  }

  static void stopRecording(WidgetRef ref, BuildContext context, String outputPath) {
    ref.read(cursorTrackingProvider.notifier).stopTracking(outputPath, context);
  }

  static void navigateToPreview(BuildContext context, String videoPath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoEditorScreen(videoPath: videoPath),
      ),
    );
  }
} 