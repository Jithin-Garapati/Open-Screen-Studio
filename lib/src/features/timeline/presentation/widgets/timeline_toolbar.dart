import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/timeline_provider.dart';
import '../../constants/timeline_colors.dart';
import '../../models/timeline_segment.dart';

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
          _buildEditButtons(),
          const SizedBox(width: 16),
          _buildLayerButtons(ref),
          const Spacer(),
          Text(
            _formatDuration(currentPosition),
            style: const TextStyle(
              color: kTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditButtons() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.content_cut, size: 20),
          onPressed: onSplitClip,
          tooltip: 'Split Clip',
        ),
        IconButton(
          icon: const Icon(Icons.crop, size: 20),
          onPressed: onTrimClip,
          tooltip: 'Trim Clip',
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: onDeleteSelected,
          tooltip: 'Delete Selected',
        ),
      ],
    );
  }

  Widget _buildLayerButtons(WidgetRef ref) {
    final timelineNotifier = ref.read(timelineProvider.notifier);

    return Row(
      children: [
        IconButton(
          icon: const Icon(
            Icons.zoom_in,
            size: 20,
            color: kAccentColor,
          ),
          onPressed: () => timelineNotifier.addLayerAtTime(
            currentPosition.inMilliseconds, 
            LayerType.zoom,
          ),
          tooltip: 'Add Zoom Layer',
        ),
        IconButton(
          icon: const Icon(
            Icons.content_cut,
            size: 20,
            color: kAccentColor,
          ),
          onPressed: () => timelineNotifier.addLayerAtTime(
            currentPosition.inMilliseconds, 
            LayerType.trim,
          ),
          tooltip: 'Add Trim Layer',
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final milliseconds = duration.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$minutes:$seconds.$milliseconds';
  }
} 