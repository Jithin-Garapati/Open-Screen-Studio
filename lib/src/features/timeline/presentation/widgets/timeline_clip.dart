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
          final timelineNotifier = ref.read(timelineProvider.notifier);
          final updatedClip = segment.copyWith(
            startTime: newStartTime,
            endTime: newStartTime + clipDuration,
          );
          timelineNotifier.updateSegment(segment, updatedClip);
          onSeek(Duration(milliseconds: newStartTime));
        }
      },
      child: Container(
        height: 80,
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
            // Trim handles
            if (segment.properties['isMainClip'] == true) ...[
              _buildTrimHandle(context, ref, true),
              _buildTrimHandle(context, ref, false),
            ],
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