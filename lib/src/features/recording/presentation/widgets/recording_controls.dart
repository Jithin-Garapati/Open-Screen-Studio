import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/recording_settings.dart';
import '../controllers/recording_controller.dart';

class RecordingControls extends ConsumerWidget {
  const RecordingControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(recordingControllerProvider);
    final controller = ref.read(recordingControllerProvider.notifier);

    return Column(
      children: [
        _buildRecordingButton(
          context: context,
          settings: settings,
          onTap: () {
            if (settings.state == RecordingState.idle) {
              controller.startRecording();
            } else if (settings.state == RecordingState.recording) {
              controller.stopRecording();
            }
          },
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Press Cmd+Shift+L to start/end Recording',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white38,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingButton({
    required BuildContext context,
    required RecordingSettings settings,
    required VoidCallback onTap,
  }) {
    final isRecording = settings.state == RecordingState.recording;
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isRecording ? Colors.red : theme.colorScheme.primary,
            isRecording ? Colors.red.shade700 : theme.colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isRecording ? Colors.red : theme.colorScheme.primary)
                .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (isRecording)
                        const BoxShadow(
                          color: Colors.white,
                          blurRadius: 12,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isRecording ? 'Stop Recording' : 'Start Recording',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 