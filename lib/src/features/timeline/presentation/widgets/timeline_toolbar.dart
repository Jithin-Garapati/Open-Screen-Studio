import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/timeline_provider.dart';
import '../../constants/timeline_colors.dart';

class TimelineToolbar extends ConsumerWidget {
  final Duration currentPosition;
  final VoidCallback onSplitClip;
  final VoidCallback onTrimClip;
  final VoidCallback onDeleteSelected;

  const TimelineToolbar({
    super.key,
    required this.currentPosition,
    required this.onSplitClip,
    required this.onTrimClip,
    required this.onDeleteSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(timelineProvider);
    final timelineNotifier = ref.read(timelineProvider.notifier);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        border: Border(
          bottom: BorderSide(color: kBorderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Left section - Basic editing controls
          _buildEditButtons(),
          const SizedBox(width: 24),
          // Center section - Playback controls
          Row(
            children: [
              _buildToolbarButton(
                icon: timeline.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                tooltip: timeline.isPlaying ? 'Pause' : 'Play',
                color: kAccentColor,
                onPressed: () => timelineNotifier.setPlaying(!timeline.isPlaying),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kBorderColor),
                ),
                child: Text(
                  _formatDuration(currentPosition),
                  style: const TextStyle(
                    color: kTextColor,
                    fontSize: 13,
                    fontFeatures: [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Right section - View controls
          Row(
            children: [
              _buildToolbarToggle(
                icon: Icons.grid_on_rounded,
                tooltip: 'Snap to Grid',
                isActive: timeline.snapEnabled,
                onPressed: () => timelineNotifier.setSnapEnabled(!timeline.snapEnabled),
              ),
              const SizedBox(width: 20),
              // Zoom controls
              _buildToolbarButton(
                icon: Icons.zoom_out_rounded,
                tooltip: 'Zoom Out',
                onPressed: () => timelineNotifier.setZoom(timeline.zoom / 1.5),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: kBorderColor),
                ),
                child: Text(
                  '${(timeline.zoom * 100).round()}%',
                  style: const TextStyle(
                    color: kTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _buildToolbarButton(
                icon: Icons.zoom_in_rounded,
                tooltip: 'Zoom In',
                onPressed: () => timelineNotifier.setZoom(timeline.zoom * 1.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditButtons() {
    return Row(
      children: [
        _buildToolbarButton(
          icon: Icons.content_cut_rounded,
          tooltip: 'Split at Playhead',
          onPressed: onSplitClip,
        ),
        const SizedBox(width: 8),
        _buildToolbarButton(
          icon: Icons.content_copy_rounded,
          tooltip: 'Trim to Selection',
          onPressed: onTrimClip,
        ),
        const SizedBox(width: 8),
        _buildToolbarButton(
          icon: Icons.delete_rounded,
          tooltip: 'Delete Selected',
          onPressed: onDeleteSelected,
        ),
      ],
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: kBorderColor),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color ?? kTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarToggle({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? kAccentColor.withOpacity(0.15) : Colors.black12,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? kAccentColor : kBorderColor,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? kAccentColor : kTextColor,
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
} 