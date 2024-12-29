import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/recording_controller.dart';
import '../widgets/window_title_bar.dart';
import '../widgets/recording_settings_section.dart';
import '../widgets/recording_controls.dart';
import '../widgets/recording_timer.dart';

class RecordingScreen extends ConsumerWidget {
  const RecordingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingSettings = ref.watch(recordingControllerProvider);

    return Scaffold(
      body: Column(
        children: [
          const WindowTitleBar(),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    RecordingSettingsSection(),
                    SizedBox(height: 24),
                    RecordingTimer(),
                    Spacer(),
                    RecordingControls(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 