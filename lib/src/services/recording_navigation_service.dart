import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/cursor_tracking_controller.dart';
import '../screens/video_preview_screen.dart';

class RecordingNavigationService {
  static void startRecording(WidgetRef ref) {
    ref.read(cursorTrackingProvider.notifier).startTracking();
  }

  static void stopRecording(WidgetRef ref, BuildContext context, String outputPath) {
    ref.read(cursorTrackingProvider.notifier).stopTracking(outputPath, context);
  }

  static void navigateToPreview(BuildContext context, String videoPath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPreviewScreen(videoPath: videoPath),
      ),
    );
  }
} 