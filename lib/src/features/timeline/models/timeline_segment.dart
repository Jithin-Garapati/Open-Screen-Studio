import 'package:flutter/material.dart';

enum SegmentType {
  normal,
  transition,
  group,
  effect,
  layer,
}

enum LayerType {
  zoom,
  trim,
  none,
}

class TimelineSegment {
  final int startTime;
  final int endTime;
  final SegmentType type;
  final Color color;
  final Map<String, dynamic> properties;
  final LayerType layerType;
  final Map<String, dynamic> layerProperties;
  final int trackIndex;
  final bool isSelected;

  const TimelineSegment({
    required this.startTime,
    required this.endTime,
    this.type = SegmentType.normal,
    required this.color,
    this.properties = const {},
    this.layerType = LayerType.none,
    this.layerProperties = const {},
    this.trackIndex = 0,
    this.isSelected = false,
  });

  bool get isValid => startTime < endTime;
  bool get isLayer => type == SegmentType.layer;

  TimelineSegment copyWith({
    int? startTime,
    int? endTime,
    SegmentType? type,
    Color? color,
    Map<String, dynamic>? properties,
    LayerType? layerType,
    Map<String, dynamic>? layerProperties,
    int? trackIndex,
    bool? isSelected,
  }) {
    return TimelineSegment(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
      color: color ?? this.color,
      properties: properties ?? this.properties,
      layerType: layerType ?? this.layerType,
      layerProperties: layerProperties ?? this.layerProperties,
      trackIndex: trackIndex ?? this.trackIndex,
      isSelected: isSelected ?? this.isSelected,
    );
  }
} 