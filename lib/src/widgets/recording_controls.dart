import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/recording_controller.dart';
import '../models/display_info.dart';
import '../widgets/screen_selector_dialog.dart';
import '../services/recording_navigation_service.dart';

class RecordingControls extends ConsumerWidget {
  const RecordingControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingState = ref.watch(recordingControllerProvider);
    final recordingController = ref.read(recordingControllerProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (recordingState.errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Text(
                recordingState.errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    final display = await showDialog<DisplayInfo>(
                      context: context,
                      builder: (context) => ScreenSelectorDialog(
                        selectedDisplay: recordingState.selectedDisplay,
                        onSelect: (display) {
                          Navigator.pop(context, display);
                        },
                      ),
                    );
                    if (display != null) {
                      recordingController.selectDisplay(display);
                    }
                  },
                  icon: const Icon(Icons.desktop_windows_outlined),
                  label: Text(
                    recordingState.selectedDisplay != null
                        ? recordingState.selectedDisplay!.name
                        : 'No display selected',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (recordingState.status != RecordingStatus.recording) ...[
                ElevatedButton.icon(
                  onPressed: recordingState.selectedDisplay != null
                      ? () {
                          recordingController.startRecording();
                          RecordingNavigationService.startRecording(ref);
                        }
                      : null,
                  icon: const Icon(Icons.fiber_manual_record),
                  label: const Text('Record'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3333),
                    foregroundColor: Colors.white,
                  ),
                ),
              ] else ...[
                if (recordingState.status == RecordingStatus.paused)
                  ElevatedButton.icon(
                    onPressed: recordingController.resumeRecording,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: recordingController.pauseRecording,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final outputPath = await recordingController.stopRecording();
                    if (outputPath != null) {
                      RecordingNavigationService.stopRecording(ref, context, outputPath);
                    }
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
} 