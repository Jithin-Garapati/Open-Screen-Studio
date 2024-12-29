import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/recording_settings.dart';
import '../controllers/recording_controller.dart';
import 'setting_button.dart';
import 'screen_selection_dialog.dart';

class RecordingSettingsSection extends ConsumerWidget {
  const RecordingSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(recordingControllerProvider);
    final controller = ref.read(recordingControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Video Settings'),
        const SizedBox(height: 16),
        SettingButton(
          icon: Icons.desktop_windows_rounded,
          label: settings.selectedScreen?.toString() ?? 'Select Screen',
          isSelected: settings.selectedScreen != null,
          onTap: () => _showScreenSelectionDialog(context),
        ),
        const SizedBox(height: 12),
        SettingButton(
          icon: Icons.fullscreen_rounded,
          label: 'Full Screen',
          isSelected: settings.mode == RecordingMode.fullScreen,
          onTap: () => controller.setMode(RecordingMode.fullScreen),
        ),
        const SizedBox(height: 32),
        _buildSectionTitle(context, 'Recording Settings'),
        const SizedBox(height: 16),
        SettingButton(
          icon: Icons.videocam_rounded,
          label: settings.selectedCamera ?? 'No Camera Selected',
          isSelected: settings.isCameraEnabled,
          onTap: () => controller.toggleCamera(),
        ),
        const SizedBox(height: 12),
        SettingButton(
          icon: Icons.mic_rounded,
          label: settings.selectedMicrophone ?? 'No Microphone Selected',
          isSelected: settings.isMicrophoneEnabled,
          onTap: () => controller.toggleMicrophone(),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }

  void _showScreenSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ScreenSelectionDialog(),
    );
  }
} 