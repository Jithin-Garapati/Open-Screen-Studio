import 'package:flutter/material.dart';

enum SegmentType {
  normal,
  transition,
  group,
}

class TimelineSegment {
  final int startTime;
  final int endTime;
  final SegmentType type;
  final Color color;
  final Map<String, dynamic> properties;

  const TimelineSegment({
    required this.startTime,
    required this.endTime,
    this.type = SegmentType.normal,
    required this.color,
    this.properties = const {},
  });

  bool get isValid => startTime < endTime;

  TimelineSegment copyWith({
    int? startTime,
    int? endTime,
    SegmentType? type,
    Color? color,
    Map<String, dynamic>? properties,
  }) {
    return TimelineSegment(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
      color: color ?? this.color,
      properties: properties ?? this.properties,
    );
  }
} 