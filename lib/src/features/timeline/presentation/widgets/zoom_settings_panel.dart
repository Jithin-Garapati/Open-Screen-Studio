import 'package:flutter/material.dart';
import '../../models/zoom_settings.dart';
import '../widgets/zoom_target_selector.dart';
import 'package:media_kit_video/media_kit_video.dart';

class ZoomSettingsPanel extends StatelessWidget {
  final ZoomSettings settings;
  final ValueChanged<ZoomSettings> onSettingsChanged;
  final VoidCallback onTargetModeToggle;
  final bool isTargetMode;
  final VideoController? videoController;
  final Duration currentPosition;
  final Size videoSize;

  const ZoomSettingsPanel({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.onTargetModeToggle,
    required this.isTargetMode,
    required this.videoController,
    required this.currentPosition,
    required this.videoSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.zoom_in,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Zoom Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isTargetMode ? Icons.location_on : Icons.location_off,
                  color: isTargetMode ? Colors.blue : Colors.white70,
                  size: 20,
                ),
                onPressed: onTargetModeToggle,
                tooltip: 'Set Zoom Target',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Frame Preview with Target Selector
          if (videoController != null)
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    // Video Frame
                    Positioned.fill(
                      child: Video(
                        controller: videoController!,
                        controls: NoVideoControls,
                      ),
                    ),
                    // Target Selector Overlay
                    if (isTargetMode)
                      Positioned.fill(
                        child: ZoomTargetSelector(
                          settings: settings,
                          onSettingsChanged: onSettingsChanged,
                          videoSize: videoSize,
                          isActive: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Zoom Scale
          Row(
            children: [
              const Text(
                'Scale',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: settings.scale,
                  min: 1.0,
                  max: 3.0,
                  divisions: 20,
                  label: '${settings.scale.toStringAsFixed(1)}x',
                  onChanged: (value) {
                    onSettingsChanged(settings.copyWith(scale: value));
                  },
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  '${settings.scale.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Duration
          Row(
            children: [
              const Text(
                'Duration',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: settings.duration.inMilliseconds.toDouble(),
                  min: 100,
                  max: 2000,
                  divisions: 19,
                  label: '${(settings.duration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                  onChanged: (value) {
                    onSettingsChanged(settings.copyWith(
                      duration: Duration(milliseconds: value.round()),
                    ));
                  },
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  '${(settings.duration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Transition Durations
          Row(
            children: [
              const Text(
                'Transitions',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    // Zoom In Duration
                    Row(
                      children: [
                        const Text(
                          'In',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: settings.transitionInDuration.inMilliseconds.toDouble(),
                            min: 100,
                            max: 1000,
                            divisions: 18,
                            label: '${(settings.transitionInDuration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                            onChanged: (value) {
                              onSettingsChanged(settings.copyWith(
                                transitionInDuration: Duration(milliseconds: value.round()),
                              ));
                            },
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: Text(
                            '${(settings.transitionInDuration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Zoom Out Duration
                    Row(
                      children: [
                        const Text(
                          'Out',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: settings.transitionOutDuration.inMilliseconds.toDouble(),
                            min: 100,
                            max: 1000,
                            divisions: 18,
                            label: '${(settings.transitionOutDuration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                            onChanged: (value) {
                              onSettingsChanged(settings.copyWith(
                                transitionOutDuration: Duration(milliseconds: value.round()),
                              ));
                            },
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: Text(
                            '${(settings.transitionOutDuration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Target Position Display
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'X: ${(settings.target.dx * 100).toStringAsFixed(1)}% '
                  'Y: ${(settings.target.dy * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 