import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/timeline_segment.dart';
import '../../providers/timeline_provider.dart';
import '../../constants/timeline_colors.dart';
import 'dart:ui' as ui;

class TimelineClip extends ConsumerWidget {
  final TimelineSegment segment;
  final double timelineWidth;
  final List<ui.Image>? thumbnails;
  final ValueChanged<Duration> onSeek;

  const TimelineClip({
    super.key,
    required this.segment,
    required this.timelineWidth,
    required this.thumbnails,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineNotifier = ref.read(timelineProvider.notifier);
    final layers = segment.properties['isMainClip'] == true 
      ? timelineNotifier.getLayersForClip(segment)
      : <TimelineSegment>[];

    return GestureDetector(
      onHorizontalDragStart: (details) {
        // Handle drag start
      },
      onHorizontalDragUpdate: (details) {
        if (segment.properties['isMainClip'] != true) return;
        
        final delta = details.delta.dx;
        final timelineDelta = (delta / timelineWidth) * segment.endTime;
        
        final newStartTime = segment.startTime + timelineDelta.round();
        final clipDuration = segment.endTime - segment.startTime;
        
        if (newStartTime >= 0 && newStartTime + clipDuration <= segment.endTime) {
          final updatedClip = segment.copyWith(
            startTime: newStartTime,
            endTime: newStartTime + clipDuration,
          );
          timelineNotifier.updateSegment(segment, updatedClip);
          onSeek(Duration(milliseconds: newStartTime));
        }
      },
      child: Container(
        height: 80 + (layers.length * 24),
        decoration: BoxDecoration(
          color: kAccentColor.withOpacity(0.15),
          border: Border.all(
            color: kAccentColor.withOpacity(0.8),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: kAccentColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Main clip content
            SizedBox(
              height: 80,
              child: Stack(
                children: [
                  // Thumbnails
                  if (thumbnails != null)
                    Row(
                      children: thumbnails!.asMap().entries.map((entry) {
                        return Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: Colors.black.withOpacity(0.2),
                                ),
                              ),
                            ),
                            child: RawImage(
                              image: entry.value,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    const Center(
                      child: Text(
                        'Generating Thumbnails...',
                        style: TextStyle(
                          color: kTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  // Trim handles for main clip
                  if (segment.properties['isMainClip'] == true) ...[
                    _buildTrimHandle(context, ref, true),
                    _buildTrimHandle(context, ref, false),
                  ],
                ],
              ),
            ),
            // Layer tracks
            if (segment.properties['isMainClip'] == true) ...[
              ...layers.map((layer) => _buildLayerTrack(layer, ref)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLayerTrack(TimelineSegment layer, WidgetRef ref) {
    final timelineNotifier = ref.read(timelineProvider.notifier);
    
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final delta = details.delta.dx;
        final timelineDelta = (delta / timelineWidth) * layer.endTime;
        
        final newStartTime = layer.startTime + timelineDelta.round();
        final layerDuration = layer.endTime - layer.startTime;
        
        if (newStartTime >= segment.startTime && 
            newStartTime + layerDuration <= segment.endTime) {
          final updatedLayer = layer.copyWith(
            startTime: newStartTime,
            endTime: newStartTime + layerDuration,
          );
          timelineNotifier.updateSegment(layer, updatedLayer);
        }
      },
      child: Container(
        height: 24,
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        decoration: BoxDecoration(
          color: layer.color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                layer.layerType.toString().split('.').last.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (layer.layerType == LayerType.zoom)
              Expanded(
                child: Slider(
                  value: layer.layerProperties['zoomLevel'] ?? 1.0,
                  min: 1.0,
                  max: 3.0,
                  onChanged: (value) {
                    timelineNotifier.updateLayerProperties(
                      layer, 
                      {'zoomLevel': value},
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrimHandle(BuildContext context, WidgetRef ref, bool isStart) {
    return Positioned(
      left: isStart ? 0 : null,
      right: isStart ? null : 0,
      top: 0,
      bottom: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          onHorizontalDragUpdate: (details) {
            final renderBox = context.findRenderObject() as RenderBox;
            final localPosition = renderBox.globalToLocal(details.globalPosition);
            final timelineWidth = renderBox.size.width;
            
            final percentage = localPosition.dx / timelineWidth;
            final time = (percentage * segment.endTime).round();
            
            final timelineNotifier = ref.read(timelineProvider.notifier);
            final updatedClip = isStart
                ? segment.copyWith(startTime: time < segment.endTime ? time : segment.startTime)
                : segment.copyWith(endTime: time > segment.startTime ? time : segment.endTime);
            
            if (updatedClip.isValid) {
              timelineNotifier.updateSegment(segment, updatedClip);
            }
          },
          child: Container(
            width: 16,
            color: Colors.transparent,
            child: Center(
              child: Container(
                width: 4,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: kAccentColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: kAccentColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 