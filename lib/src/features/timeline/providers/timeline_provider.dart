import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../models/timeline_segment.dart';
import 'dart:math' as math;

class TimelineState {
  final List<TimelineSegment> segments;
  final Set<String> selectedSegments;
  final bool isPlaying;
  final double zoom;
  final bool snapEnabled;
  final Duration currentTime;
  final int trackCount;

  const TimelineState({
    this.segments = const [],
    this.selectedSegments = const {},
    this.isPlaying = false,
    this.zoom = 1.0,
    this.snapEnabled = true,
    this.currentTime = Duration.zero,
    this.trackCount = 1,
  });

  TimelineState copyWith({
    List<TimelineSegment>? segments,
    Set<String>? selectedSegments,
    bool? isPlaying,
    double? zoom,
    bool? snapEnabled,
    Duration? currentTime,
    int? trackCount,
  }) {
    return TimelineState(
      segments: segments ?? this.segments,
      selectedSegments: selectedSegments ?? this.selectedSegments,
      isPlaying: isPlaying ?? this.isPlaying,
      zoom: zoom ?? this.zoom,
      snapEnabled: snapEnabled ?? this.snapEnabled,
      currentTime: currentTime ?? this.currentTime,
      trackCount: trackCount ?? this.trackCount,
    );
  }
}

class TimelineNotifier extends StateNotifier<TimelineState> {
  TimelineNotifier() : super(const TimelineState());

  void setPlaying(bool playing) {
    state = state.copyWith(isPlaying: playing);
  }

  void setZoom(double zoom) {
    state = state.copyWith(zoom: zoom.clamp(0.1, 5.0));
  }

  void setSnapEnabled(bool enabled) {
    state = state.copyWith(snapEnabled: enabled);
  }

  void addSegment(TimelineSegment segment) {
    state = state.copyWith(
      segments: [...state.segments, segment],
    );
  }

  void updateSegment(TimelineSegment oldSegment, TimelineSegment newSegment) {
    final segments = state.segments.toList();
    final index = segments.indexOf(oldSegment);
    if (index != -1) {
      segments[index] = newSegment;
      state = state.copyWith(segments: segments);
      updateTrackOffsets();  // Update track offsets after segment changes
    }
  }

  void removeSegment(TimelineSegment segment) {
    final segmentId = segment.properties['id'] as String?;
    if (segmentId == null) return;
    
    state = state.copyWith(
      segments: state.segments.where((s) => s != segment).toList(),
      selectedSegments: state.selectedSegments.where((id) => id != segmentId).toSet(),
    );
  }

  void selectSegment(TimelineSegment segment) {
    state = state.copyWith(
      segments: state.segments.map((s) => s == segment 
        ? s.copyWith(isSelected: true) 
        : s.copyWith(isSelected: false)
      ).toList(),
    );
  }

  void deselectAllSegments() {
    state = state.copyWith(
      segments: state.segments.map((s) => s.copyWith(isSelected: false)).toList(),
    );
  }

  void clearSelection() {
    state = state.copyWith(selectedSegments: const {});
  }

  void deleteSelectedSegments() {
    if (state.selectedSegments.isEmpty) return;
    
    final segments = state.segments.toList();
    segments.removeWhere((segment) => 
      state.selectedSegments.contains(segment.properties['id']));
    
    state = state.copyWith(
      segments: segments,
      selectedSegments: const {},
    );
    updateTrackOffsets();
  }

  void splitSegmentAtTime(int timestamp) {
    // Implementation for splitting segment at timestamp
  }

  void undo() {
    // Implementation for undo
  }

  void redo() {
    // Implementation for redo
  }

  void addEffectLayer(TimelineSegment mainClip, LayerType layerType) {
    final effectSegment = TimelineSegment(
      startTime: mainClip.startTime,
      endTime: mainClip.endTime,
      type: SegmentType.layer,
      layerType: layerType,
      color: mainClip.color.withOpacity(0.7),
      properties: {'parentClipId': mainClip.properties['id']},
      layerProperties: layerType == LayerType.zoom 
        ? {'zoomLevel': 1.5} 
        : {'trimStart': 0, 'trimEnd': 0},
    );
    
    state = state.copyWith(
      segments: [...state.segments, effectSegment],
    );
  }

  void updateEffectProperties(TimelineSegment layerSegment, Map<String, dynamic> newProperties) {
    if (!layerSegment.isLayer) return;
    
    final updatedSegment = layerSegment.copyWith(
      layerProperties: {...layerSegment.layerProperties, ...newProperties},
    );
    
    updateSegment(layerSegment, updatedSegment);
  }

  List<TimelineSegment> getEffectsForClip(TimelineSegment mainClip) {
    return state.segments.where((segment) => 
      segment.isLayer && 
      segment.properties['parentClipId'] == mainClip.properties['id']
    ).toList();
  }

  TimelineSegment? findClipAtTime(int timestamp) {
    // Find any main clip that contains this timestamp
    for (final segment in state.segments) {
      if (segment.properties['isMainClip'] == true &&
          timestamp >= segment.startTime &&
          timestamp <= segment.endTime) {
        return segment;
      }
    }
    return null;
  }

  void addEffectLayerAtTime(int timestamp, LayerType layerType) {
    final mainClip = findClipAtTime(timestamp);
    if (mainClip == null) return;

    // Calculate effect duration (default to 2 seconds or clip remaining duration)
    final remainingDuration = mainClip.endTime - timestamp;
    final effectDuration = math.min(2000, remainingDuration);

    final effectSegment = TimelineSegment(
      startTime: timestamp,
      endTime: timestamp + effectDuration,
      type: SegmentType.layer,
      layerType: layerType,
      color: mainClip.color.withOpacity(0.7),
      properties: {'parentClipId': mainClip.properties['id']},
      layerProperties: layerType == LayerType.zoom 
        ? {'zoomLevel': 1.5} 
        : {'trimStart': 0, 'trimEnd': 0},
    );
    
    state = state.copyWith(
      segments: [...state.segments, effectSegment],
    );
  }

  void updateLayerTracks() {
    // Get all layer segments
    final layers = state.segments.where((s) => s.isLayer).toList();
    
    // Sort layers by start time to ensure consistent track assignment
    layers.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    // Track assignments and height scales
    final Map<String, int> trackAssignments = {};
    final Map<String, double> heightScales = {};
    
    for (final layer in layers) {
      // Find overlapping layers that have already been assigned tracks
      final overlappingLayers = layers
          .where((other) => 
            trackAssignments.containsKey(other.properties['id']) &&
            layer.startTime < other.endTime && 
            layer.endTime > other.startTime
          )
          .toList();
      
      if (overlappingLayers.isEmpty) {
        // No overlaps, use full height
        trackAssignments[layer.properties['id']] = 0;
        heightScales[layer.properties['id']] = 1.0;
      } else {
        // Calculate height scale based on number of overlaps
        // Use a more balanced scale that doesn't shrink too much
        final scale = math.max(0.7, 1.0 - (overlappingLayers.length * 0.15));  // Minimum 70% height
        heightScales[layer.properties['id']] = scale;
        
        // Assign tracks with fixed spacing
        final trackNum = overlappingLayers.length;
        trackAssignments[layer.properties['id']] = trackNum;
        
        // Update overlapping layers to use same scale
        for (final other in overlappingLayers) {
          heightScales[other.properties['id']] = scale;
        }
      }
    }
    
    // Update all layers with their track assignments and height scales
    final updatedSegments = state.segments.map((segment) {
      if (segment.isLayer && trackAssignments.containsKey(segment.properties['id'])) {
        return segment.copyWith(
          properties: {
            ...segment.properties,
            'trackOffset': trackAssignments[segment.properties['id']],
            'heightScale': heightScales[segment.properties['id']] ?? 1.0
          }
        );
      }
      return segment;
    }).toList();
    
    state = state.copyWith(segments: updatedSegments);
  }

  void addLayerAtTime(int timestamp, LayerType type) {
    final segments = state.segments.toList();
    
    // Create a new layer segment
    final newLayer = TimelineSegment(
      startTime: timestamp,
      endTime: timestamp + 3000,  // 3 seconds default duration
      type: SegmentType.layer,
      layerType: type,
      color: type == LayerType.zoom ? Colors.blue : Colors.green,
      properties: {
        'isLayer': true,
        'layerType': type,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    
    segments.add(newLayer);
    state = state.copyWith(segments: segments);
    updateTrackOffsets();
  }

  void updateLayerProperties(TimelineSegment layerSegment, Map<String, dynamic> newProperties) {
    if (!layerSegment.isLayer) return;
    
    final updatedSegment = layerSegment.copyWith(
      layerProperties: {...layerSegment.layerProperties, ...newProperties},
    );
    
    updateSegment(layerSegment, updatedSegment);
  }

  List<TimelineSegment> getLayersForClip(TimelineSegment mainClip) {
    return state.segments.where((segment) => 
      segment.isLayer && 
      segment.properties['parentClipId'] == mainClip.properties['id']
    ).toList();
  }

  List<TimelineSegment> getLayersInTrack(int trackIndex) {
    return state.segments.where((segment) => 
      segment.isLayer && segment.trackIndex == trackIndex
    ).toList();
  }

  void updateTrackOffsets() {
    final segments = state.segments.toList();
    final layerSegments = segments.where((s) => s.isLayer).toList();
    
    // Sort layers by start time to ensure consistent track assignment
    layerSegments.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    // Track assignments map to store track numbers
    final trackAssignments = <String, int>{};
    
    for (final layer in layerSegments) {
      final layerId = layer.properties['id'] as String?;
      if (layerId == null) continue;

      // Find all layers that overlap with this one
      final overlappingLayers = layerSegments
          .where((s) => s != layer)
          .where((s) => _doLayersOverlap(layer, s))
          .toList();

      if (overlappingLayers.isEmpty) {
        // If no overlaps, assign to track 0
        trackAssignments[layerId] = 0;
      } else {
        // Find the lowest available track number that doesn't conflict (max 1 for 2 total tracks)
        var trackNum = 0;
        while (trackNum <= 1) {  // Limit to 2 tracks (0, 1)
          final trackConflict = overlappingLayers.any((other) {
            final otherId = other.properties['id'] as String?;
            return otherId != null && 
                   trackAssignments.containsKey(otherId) && 
                   trackAssignments[otherId] == trackNum;
          });
          
          if (!trackConflict) {
            trackAssignments[layerId] = trackNum;
            break;
          }
          trackNum++;
        }
        // If all tracks are taken, use track 1 (topmost)
        if (trackNum > 1) {
          trackAssignments[layerId] = 1;
        }
      }
    }
    
    // Apply track assignments to segments
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (segment.isLayer) {
        final layerId = segment.properties['id'] as String?;
        if (layerId != null && trackAssignments.containsKey(layerId)) {
          segments[i] = segment.copyWith(
            properties: {
              ...segment.properties,
              'trackOffset': trackAssignments[layerId],
            },
          );
        }
      }
    }
    
    state = state.copyWith(segments: segments);
  }
  
  bool _doLayersOverlap(TimelineSegment a, TimelineSegment b) {
    // Add a small threshold to prevent track changes for tiny overlaps
    const threshold = 50; // milliseconds
    return (a.startTime - threshold) < b.endTime && 
           (a.endTime + threshold) > b.startTime;
  }

  void selectSegments(List<TimelineSegment> segments) {
    final segmentIds = segments
        .map((s) => s.properties['id'] as String?)
        .where((id) => id != null)
        .cast<String>()
        .toSet();
    
    state = state.copyWith(selectedSegments: segmentIds);
  }
}

final timelineProvider = StateNotifierProvider<TimelineNotifier, TimelineState>((ref) {
  return TimelineNotifier();
}); 