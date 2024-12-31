import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../config/window_config.dart';
import '../controllers/recording_controller.dart';
import '../models/display_info.dart';
import 'video_editor_screen.dart';
import '../services/audio_device_service.dart';
import '../widgets/preview_section.dart';
import '../features/recording/presentation/widgets/screen_selection_dialog.dart' as screen_dialog;
import '../features/recording/domain/entities/screen_info.dart';

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
  OverlayEntry? _overlayEntry;
  Future<void> Function()? _windowCleanup;

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

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _windowCleanup?.call();
    _windowCleanup = null;
  }

  void _showDisplaySelection(BuildContext context, List<DisplayInfo> displays, DisplayInfo? selectedDisplay) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final buttonPosition = button.localToGlobal(Offset.zero);
    
    // Calculate needed height based on number of items (displays + window option)
    final itemCount = displays.length + 1; // +1 for window option
    final menuHeight = (itemCount * 40.0) + 16.0;
    const menuWidth = 250.0;
    
    // Expand window first
    _windowCleanup = await temporarilyExpandWindowHeight(menuHeight);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            top: 52, // Height of button (36) + top padding (16)
            left: 16, // Left padding
            width: menuWidth,
            child: Material(
              color: const Color(0xFF1E1E1E),
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...displays.map((display) => InkWell(
                      onTap: () {
                        ref.read(recordingControllerProvider.notifier).selectDisplay(display);
                        _removeOverlay();
                      },
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    )),
                    // Add window selection option
                    InkWell(
                      onTap: () {
                        _removeOverlay();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Window selection coming soon!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: const Row(
                          children: [
                            Icon(Icons.window_outlined, 
                              color: Colors.white70, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Select Window (Coming Soon)',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _showWindowSelection(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => const screen_dialog.ScreenSelectionDialog(),
    );
  }

  // Modify the display selection button to use our custom dropdown
  Widget _buildDisplaySelectionButton(AsyncValue<List<DisplayInfo>> displays) {
    final recordingState = ref.watch(recordingControllerProvider);
    final selectedScreen = recordingState.selectedScreen;
    final isWindow = selectedScreen?.type == ScreenType.window;

    return displays.when(
      data: (displayList) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 250),
        child: IntrinsicWidth(
          child: GestureDetector(
            onTap: () => _showDisplaySelection(
              context, 
              displayList,
              recordingState.selectedDisplay,
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
                      Icon(
                        isWindow ? Icons.window_rounded : Icons.desktop_windows_outlined,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          selectedScreen?.windowTitle ?? 
                          recordingState.selectedDisplay?.name ?? 
                          'Select a window',
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
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displays = ref.watch(availableScreensProvider);
    final recordingState = ref.watch(recordingControllerProvider);
    final controller = ref.watch(recordingControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => windowManager.startDragging(),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
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
                  padding: const EdgeInsets.all(16),
                  child: FutureBuilder(
                    future: controller.ensureInitialized(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                'Initializing...',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                'Error initializing: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return AnimatedSwitcher(
                        duration: _animationDuration,
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        child: isRecording
                            ? _buildRecordingControls()
                            : Column(
                                children: [
                                  // Top bar: All controls except settings and record
                                  Row(
                                    children: [
                                      _buildDisplaySelectionButton(displays),
                                      const SizedBox(width: 12),
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
                                      _buildToggleOption(
                                        icon: Icons.volume_off_outlined,
                                        activeIcon: Icons.volume_up_outlined,
                                        isActive: recordingState.isSystemAudioEnabled,
                                        onChanged: (value) {
                                          ref.read(recordingControllerProvider.notifier).toggleSystemAudio();
                                          if (!value) {
                                            ref.read(selectedAudioDeviceProvider.notifier).state = null;
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  
                                  // Middle section: Preview or Instructions
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: ref.watch(recordingControllerProvider).selectedDisplay != null
                                          ? PreviewSection(
                                              selectedDisplay: ref.watch(recordingControllerProvider).selectedDisplay,
                                              isMicEnabled: isMicrophoneEnabled,
                                              isSystemAudioEnabled: recordingState.isSystemAudioEnabled,
                                            )
                                          : Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.videocam_outlined,
                                                    size: 24,
                                                    color: Colors.white.withOpacity(0.24),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Select a display to start recording',
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(0.3),
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                  ),
                                  
                                  // Bottom bar: Settings and Record button
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildOptionButton(
                                        icon: Icons.settings_outlined,
                                        isSelected: false,
                                        onPressed: () {},
                                      ),
                                      Container(
                                        height: 40,
                                        constraints: const BoxConstraints(maxWidth: 140),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                          ),
                                          icon: const Icon(Icons.fiber_manual_record, size: 16),
                                          label: const Text(
                                            'Record',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          onPressed: () async {
                                            setState(() => isRecording = true);
                                            await ref.read(recordingControllerProvider.notifier)
                                                .startRecording();
                                            await setWindowForRecording();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      );
                    },
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
    return SizedBox(
      width: 32,
      height: label != null ? 56 : 32,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
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
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordingControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: Row(
          key: const ValueKey('recording'),
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Timer section
            Flexible(
              child: Container(
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
                          builder: (context) => VideoEditorScreen(videoPath: videoPath),
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