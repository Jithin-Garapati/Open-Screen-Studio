import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/display_info.dart';
import '../controllers/recording_controller.dart';

class ScreenSelectorDialog extends ConsumerWidget {
  final DisplayInfo? selectedDisplay;
  final void Function(DisplayInfo) onSelect;

  const ScreenSelectorDialog({
    super.key,
    this.selectedDisplay,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingController = ref.read(recordingControllerProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Display selector
        Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Close button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                    child: Container(
                      width: 48,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white.withOpacity(0.8),
                        size: 20,
                      ),
                    ),
                  ),
                ),
                // Display selector
                FutureBuilder<List<DisplayInfo>>(
                  future: recordingController.getDisplays(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        width: 48,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      );
                    }

                    final displays = snapshot.data ?? [];
                    if (displays.isEmpty) {
                      return const SizedBox(width: 48);
                    }

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (displays.isNotEmpty) {
                            onSelect(displays[0]); // Select first display for now
                          }
                        },
                        child: Container(
                          width: 48,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: Colors.white.withOpacity(0.1),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Icon(
                            Icons.desktop_windows_outlined,
                            color: Colors.white.withOpacity(0.8),
                            size: 20,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Window selector (disabled for now)
                _buildIconButton(
                  Icons.web_asset_outlined,
                  isEnabled: false,
                ),
                // Area selector (disabled for now)
                _buildIconButton(
                  Icons.crop_square_outlined,
                  isEnabled: false,
                ),
                // Device selector (disabled for now)
                _buildIconButton(
                  Icons.phone_iphone_outlined,
                  isEnabled: false,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Options bar
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Camera
              _buildStatusItem(
                Icons.videocam_off_outlined,
                'No camera',
              ),
              // Microphone
              _buildStatusItem(
                Icons.mic_off_outlined,
                'No microphone',
              ),
              // System audio
              _buildStatusItem(
                Icons.volume_off_outlined,
                'No system audio',
              ),
              // Settings button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // TODO: Show settings
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: double.infinity,
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.settings_outlined,
                      color: Colors.white.withOpacity(0.8),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, {bool isEnabled = true}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? () {} : null,
        child: Container(
          width: 48,
          height: double.infinity,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white.withOpacity(isEnabled ? 0.8 : 0.3),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white.withOpacity(0.8),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
} 