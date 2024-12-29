import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../config/window_config.dart';
import '../controllers/recording_controller.dart';
import '../models/display_info.dart';
import 'video_preview_screen.dart';
import '../widgets/audio_device_selection_dialog.dart';
import '../services/audio_device_service.dart';

class RecordingSetupScreen extends ConsumerStatefulWidget {
  const RecordingSetupScreen({super.key});

  @override
  ConsumerState<RecordingSetupScreen> createState() => _RecordingSetupScreenState();
}

class _RecordingSetupScreenState extends ConsumerState<RecordingSetupScreen> {
  bool isMicrophoneEnabled = false;
  bool isCameraEnabled = false;
  bool isSystemAudioEnabled = false;
  bool isRecording = false;
  int _recordingSeconds = 0;
  List<AudioDevice> _audioDevices = [];
  final Duration _animationDuration = const Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _loadAudioDevices();
  }

  Future<void> _loadAudioDevices() async {
    final devices = await ref.read(audioDeviceServiceProvider).getAudioOutputDevices();
    setState(() {
      _audioDevices = devices;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displays = ref.watch(availableScreensProvider);
    final recordingState = ref.watch(recordingControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => windowManager.startDragging(),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          margin: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: AnimatedSwitcher(
                    duration: _animationDuration,
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: isRecording
                        ? _buildRecordingControls()
                        : Row(
                            key: const ValueKey('setup'),
                            children: [
                              // Left section: Display selection
                              displays.when(
                                data: (displayList) => ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 250),
                                  child: IntrinsicWidth(
                                    child: PopupMenuButton<DisplayInfo>(
                                      offset: const Offset(0, 40),
                                      position: PopupMenuPosition.under,
                                      useRootNavigator: true,
                                      constraints: const BoxConstraints(
                                        minWidth: 200,
                                        maxWidth: 300,
                                      ),
                                      clipBehavior: Clip.none,
                                      itemBuilder: (context) => displayList.map((display) => 
                                        PopupMenuItem<DisplayInfo>(
                                          height: 40,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          value: display,
                                          child: Row(
                                            children: [
                                              const Icon(Icons.desktop_windows_outlined, 
                                                color: Colors.white70, size: 16),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  display.name,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ).toList(),
                                      onSelected: (display) {
                                        ref.read(recordingControllerProvider.notifier)
                                           .selectDisplay(display);
                                      },
                                      color: const Color(0xFF1E1E1E),
                                      elevation: 8,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: Colors.white.withOpacity(0.1),
                                        ),
                                      ),
                                      child: Container(
                                        height: 36,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.desktop_windows_outlined, 
                                                  color: Colors.white70, size: 16),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    recordingState.selectedDisplay?.name ?? displayList.first.name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Icon(Icons.expand_more, 
                                              color: Colors.white70, size: 18),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                loading: () => const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                                  ),
                                ),
                                error: (error, stack) => const Icon(
                                  Icons.error_outline,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                              ),

                              // Center section: Recording options
                              const SizedBox(width: 12),
                              _buildOptionButton(
                                icon: Icons.window_outlined,
                                isSelected: false,
                                onPressed: () {},
                              ),
                              const SizedBox(width: 8),
                              _buildOptionButton(
                                icon: Icons.crop_square_outlined,
                                isSelected: false,
                                onPressed: () {},
                              ),
                              const SizedBox(width: 16),
                              Container(
                                width: 1,
                                height: 24,
                                color: Colors.white.withOpacity(0.1),
                              ),
                              const SizedBox(width: 16),
                              _buildToggleOption(
                                icon: Icons.videocam_off_outlined,
                                activeIcon: Icons.videocam_outlined,
                                isActive: isCameraEnabled,
                                onChanged: (value) => setState(() => isCameraEnabled = value),
                              ),
                              const SizedBox(width: 12),
                              _buildToggleOption(
                                icon: Icons.mic_off_outlined,
                                activeIcon: Icons.mic_outlined,
                                isActive: isMicrophoneEnabled,
                                onChanged: (value) => setState(() => isMicrophoneEnabled = value),
                              ),
                              const SizedBox(width: 12),
                              // Audio toggle button
                              Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: recordingState.isSystemAudioEnabled 
                                    ? Colors.white.withOpacity(0.1) 
                                    : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: recordingState.isSystemAudioEnabled
                                        ? Colors.transparent
                                        : Colors.white.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    recordingState.isSystemAudioEnabled
                                        ? Icons.volume_up_outlined
                                        : Icons.volume_off_outlined,
                                    size: 16,
                                    color: recordingState.isSystemAudioEnabled
                                        ? Colors.white
                                        : Colors.red.withOpacity(0.7),
                                  ),
                                  onPressed: () {
                                    ref.read(recordingControllerProvider.notifier).toggleSystemAudio();
                                    if (!recordingState.isSystemAudioEnabled) {
                                      ref.read(selectedAudioDeviceProvider.notifier).state = null;
                                    }
                                  },
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  tooltip: recordingState.isSystemAudioEnabled ? 'Turn Off Computer Audio' : 'Turn On Computer Audio',
                                ),
                              ),
                              // Audio device dropdown
                              PopupMenuButton<AudioDevice>(
                                offset: const Offset(0, 40),
                                position: PopupMenuPosition.under,
                                tooltip: 'Select Audio Device',
                                useRootNavigator: true,
                                enabled: recordingState.isSystemAudioEnabled,
                                constraints: const BoxConstraints(
                                  minWidth: 200,
                                  maxWidth: 300,
                                ),
                                clipBehavior: Clip.none,
                                color: const Color(0xFF1E1E1E),
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Container(
                                  width: 24,
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    Icons.expand_more,
                                    size: 16,
                                    color: recordingState.isSystemAudioEnabled
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                itemBuilder: (context) {
                                  final items = <PopupMenuItem<AudioDevice>>[];

                                  // Show loading state if no devices are loaded yet
                                  if (_audioDevices.isEmpty) {
                                    items.add(
                                      PopupMenuItem<AudioDevice>(
                                        value: null,
                                        enabled: false,
                                        height: 40,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Loading devices...',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  } else {
                                    // Add all available audio devices
                                    items.addAll(
                                      _audioDevices.map((device) => PopupMenuItem<AudioDevice>(
                                        value: device,
                                        height: 40,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.volume_up_outlined,
                                              size: 16,
                                              color: Colors.white70,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                device.name,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                    );
                                  }

                                  return items;
                                },
                                onSelected: (device) {
                                  ref.read(selectedAudioDeviceProvider.notifier).state = device;
                                },
                              ),

                              // Right section: Actions
                              const Spacer(),
                              Container(
                                height: 36,
                                constraints: const BoxConstraints(maxWidth: 120),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  icon: const Icon(Icons.fiber_manual_record, size: 16),
                                  label: const Text(
                                    'Record',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  onPressed: () async {
                                    setState(() => isRecording = true);
                                    await ref.read(recordingControllerProvider.notifier)
                                        .startRecording();
                                    await setWindowForRecording();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildOptionButton(
                                icon: Icons.settings_outlined,
                                isSelected: false,
                                onPressed: () {},
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        icon: Icon(icon, size: 16),
        color: Colors.white70,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required IconData activeIcon,
    required bool isActive,
    required ValueChanged<bool> onChanged,
    String? label,
  }) {
    return Container(
      width: 32,
      height: 36,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: IconButton(
              icon: Icon(
                isActive ? activeIcon : icon,
                size: 16,
              ),
              color: isActive ? Colors.white : Colors.white70,
              padding: EdgeInsets.zero,
              onPressed: () => onChanged(!isActive),
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
                maxWidth: 32,
                maxHeight: 32,
              ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 2),
            SizedBox(
              height: 12,
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white70,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordingControls() {
    return SizedBox(
      width: double.infinity,
      child: Row(
        key: const ValueKey('recording'),
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Timer section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                StreamBuilder<Duration>(
                  stream: Stream.periodic(const Duration(seconds: 1))
                      .map((_) => Duration(seconds: _recordingSeconds++)),
                  builder: (context, snapshot) {
                    final duration = snapshot.data ?? Duration.zero;
                    return Text(
                      _formatDuration(duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Controls section
          Container(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildControlButton(
                  icon: Icons.pause_rounded,
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
                _buildControlButton(
                  icon: Icons.stop_rounded,
                  onPressed: () async {
                    setState(() => isRecording = false);
                    _recordingSeconds = 0;
                    final videoPath = await ref.read(recordingControllerProvider.notifier)
                        .stopRecording();
                    await setupWindow(initialSize: WindowSizes.recording);
                    if (videoPath != null && context.mounted) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => VideoPreviewScreen(videoPath: videoPath),
                      ));
                    }
                  },
                ),
                const SizedBox(width: 8),
                _buildControlButton(
                  icon: Icons.refresh_rounded,
                  onPressed: () async {
                    await ref.read(recordingControllerProvider.notifier).stopRecording();
                    await ref.read(recordingControllerProvider.notifier).startRecording();
                  },
                ),
                const SizedBox(width: 8),
                _buildControlButton(
                  icon: Icons.delete_outline_rounded,
                  color: Colors.red.withOpacity(0.7),
                  onPressed: () async {
                    setState(() => isRecording = false);
                    await ref.read(recordingControllerProvider.notifier).stopRecording();
                    await setupWindow(initialSize: WindowSizes.recording);
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (context) => const RecordingSetupScreen(),
                      ));
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        icon: Icon(icon, size: 16),
        color: color ?? Colors.white70,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        constraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }
} 