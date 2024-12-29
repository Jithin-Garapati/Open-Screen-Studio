import 'package:flutter/material.dart';

enum SegmentType {
  normal,
  zoom,
  speedUp,
  slowDown,
  cut,
  transition,
}

class TimelineSegment {
  final int startTime;  // in milliseconds
  final int endTime;    // in milliseconds
  final SegmentType type;
  final Color color;
  final Map<String, dynamic> properties;

  const TimelineSegment({
    required this.startTime,
    required this.endTime,
    this.type = SegmentType.normal,
    this.color = Colors.blue,
    this.properties = const {},
  });

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

  Duration get duration => Duration(milliseconds: endTime - startTime);
  
  bool get isValid => startTime < endTime;

  bool overlaps(TimelineSegment other) {
    return startTime < other.endTime && endTime > other.startTime;
  }

  bool contains(int timeMs) {
    return timeMs >= startTime && timeMs <= endTime;
  }

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'type': type.toString(),
      'color': color.value,
      'properties': properties,
    };
  }

  factory TimelineSegment.fromJson(Map<String, dynamic> json) {
    return TimelineSegment(
      startTime: json['startTime'] as int,
      endTime: json['endTime'] as int,
      type: SegmentType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => SegmentType.normal,
      ),
      color: Color(json['color'] as int),
      properties: json['properties'] as Map<String, dynamic>,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimelineSegment &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(startTime, endTime, type);
} 