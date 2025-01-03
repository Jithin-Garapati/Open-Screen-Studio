import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/timeline_provider.dart';
import '../../constants/timeline_colors.dart';
import '../../models/timeline_segment.dart';
import '../painters/timeline_grid_painter.dart';
import '../painters/timeline_ruler_painter.dart';
import '../painters/timeline_grid_overlay_painter.dart';
import 'timeline_clip.dart';
import 'timeline_playhead.dart';
import 'timeline_toolbar.dart';

class TimelineEditor extends ConsumerStatefulWidget {
  final Duration videoDuration;
  final Duration currentPosition;
  final ValueChanged<Duration> onSeek;
  final String videoPath;

  const TimelineEditor({
    super.key,
    required this.videoDuration,
    required this.currentPosition,
    required this.onSeek,
    required this.videoPath,
  });

  @override
  ConsumerState<TimelineEditor> createState() => _TimelineEditorState();
}

class _TimelineEditorState extends ConsumerState<TimelineEditor> with TickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _scrollAnimationController;
  bool _isScrolling = false;
  Timer? _scrollEndTimer;
  final bool _isDragging = false;
  bool _isDraggingPlayhead = false;
  List<ui.Image>? _thumbnails;
  final bool _isGeneratingThumbnails = false;
  double? _timelineDragPosition;
  bool _isMovingPlayhead = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scrollController.addListener(_handleScroll);
    _generateThumbnails();
  }

  void _handleScroll() {
    if (!_isScrolling) {
      setState(() => _isScrolling = true);
    }

    _scrollEndTimer?.cancel();
    _scrollEndTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() => _isScrolling = false);
      }
    });
  }

  Future<void> _generateThumbnails() async {
    // Implement thumbnail generation logic here
  }

  void _handleTimelineSeek(DragUpdateDetails details, BoxConstraints constraints) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final timelineWidth = constraints.maxWidth * ref.read(timelineProvider).zoom;
    
    _seekToPosition(localPosition.dx, timelineWidth, constraints);
  }

  void _handleTimelineClick(TapUpDetails details, BoxConstraints constraints) {
    if (_isDragging) return;
    
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final timelineWidth = constraints.maxWidth * ref.read(timelineProvider).zoom;
    
    _seekToPosition(localPosition.dx, timelineWidth, constraints);
  }

  void _seekToPosition(double localX, double timelineWidth, BoxConstraints constraints) {
    final scrollOffset = _scrollController.offset;
    final viewportWidth = constraints.maxWidth;
    
    // Calculate the position relative to the timeline
    double effectiveX = localX + scrollOffset;
    
    // Clamp the position to the timeline bounds
    effectiveX = effectiveX.clamp(0, timelineWidth);
    
    // Calculate the seek position
    final seekPosition = (effectiveX / timelineWidth) * widget.videoDuration.inMilliseconds;
    widget.onSeek(Duration(milliseconds: seekPosition.round()));
    
    // Auto-scroll if near edges
    if (localX < 100) {
      _scrollController.jumpTo((_scrollController.offset - 20).clamp(0, timelineWidth - viewportWidth));
    } else if (localX > viewportWidth - 100) {
      _scrollController.jumpTo((_scrollController.offset + 20).clamp(0, timelineWidth - viewportWidth));
    }
  }

  void _handlePlayheadDragUpdate(double visualPosition, BoxConstraints constraints) {
    final timelineWidth = constraints.maxWidth * ref.read(timelineProvider).zoom;
    final viewportWidth = constraints.maxWidth;
    
    // Auto-scroll if near edges
    final localX = visualPosition - _scrollController.offset;
    if (localX < 100) {
      final scrollAmount = (100 - localX) * 0.5;
      final newOffset = (_scrollController.offset - scrollAmount).clamp(0.0, timelineWidth - viewportWidth);
      _scrollController.jumpTo(newOffset);
    } else if (localX > viewportWidth - 100) {
      final scrollAmount = (localX - (viewportWidth - 100)) * 0.5;
      final newOffset = (_scrollController.offset + scrollAmount).clamp(0.0, timelineWidth - viewportWidth);
      _scrollController.jumpTo(newOffset);
    }
  }

  void _handlePlayheadDragEnd(double visualPosition, BoxConstraints constraints) {
    final timelineWidth = constraints.maxWidth * ref.read(timelineProvider).zoom;
    
    // Calculate the final position and seek
    final clampedPosition = visualPosition.clamp(0.0, timelineWidth);
    final seekPosition = (clampedPosition / timelineWidth) * widget.videoDuration.inMilliseconds;
    widget.onSeek(Duration(milliseconds: seekPosition.round()));
    
    setState(() => _isDraggingPlayhead = false);
  }

  void _handleTimelineDragStart(DragStartDetails details, BoxConstraints constraints) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final timelineWidth = constraints.maxWidth * ref.read(timelineProvider).zoom;
    
    setState(() {
      _isDraggingPlayhead = true;
      _isMovingPlayhead = true;
      _timelineDragPosition = localPosition.dx + _scrollController.offset;
    });
  }

  void _handleTimelineDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (!_isDraggingPlayhead) return;
    
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final timelineWidth = constraints.maxWidth * ref.read(timelineProvider).zoom;
    final viewportWidth = constraints.maxWidth;
    
    setState(() {
      _timelineDragPosition = (localPosition.dx + _scrollController.offset).clamp(0.0, timelineWidth);
    });
    
    // Auto-scroll if near edges
    if (localPosition.dx < 100) {
      final scrollAmount = (100 - localPosition.dx) * 0.5;
      final newOffset = (_scrollController.offset - scrollAmount).clamp(0.0, timelineWidth - viewportWidth);
      _scrollController.jumpTo(newOffset);
    } else if (localPosition.dx > viewportWidth - 100) {
      final scrollAmount = (localPosition.dx - (viewportWidth - 100)) * 0.5;
      final newOffset = (_scrollController.offset + scrollAmount).clamp(0.0, timelineWidth - viewportWidth);
      _scrollController.jumpTo(newOffset);
    }
  }

  void _handleTimelineDragEnd(DragEndDetails details, BoxConstraints constraints) {
    if (!_isDraggingPlayhead) return;
    
    final timelineWidth = constraints.maxWidth * ref.read(timelineProvider).zoom;
    if (_timelineDragPosition != null) {
      final seekPosition = (_timelineDragPosition! / timelineWidth) * widget.videoDuration.inMilliseconds;
      widget.onSeek(Duration(milliseconds: seekPosition.round()));
    }
    
    setState(() {
      _isDraggingPlayhead = false;
      _timelineDragPosition = null;
      // Keep _isMovingPlayhead true for a moment to show the animation
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() => _isMovingPlayhead = false);
        }
      });
    });
  }

  void _handleTimelineTap(TapDownDetails details, BoxConstraints constraints) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final timelineWidth = constraints.maxWidth * ref.read(timelineProvider).zoom;
    
    setState(() => _isMovingPlayhead = true);
    
    _seekToPosition(localPosition.dx, timelineWidth, constraints);
    
    // Reset the moving state after animation
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() => _isMovingPlayhead = false);
      }
    });
  }

  double _calculateTimelineHeight(TimelineState timeline) {
    // Get the maximum track offset used
    final maxTrackOffset = timeline.segments
        .where((s) => s.isLayer)
        .map((s) => s.properties['trackOffset'] ?? 0)
        .fold(0, (max, value) => math.max(max, value as int));
    
    // Calculate height based on number of tracks
    // Base height (for main clip) + (number of layer tracks * track height) + padding
    return 80.0 + ((maxTrackOffset + 1) * 64.0) + 16.0;
  }

  @override
  void dispose() {
    _scrollEndTimer?.cancel();
    _scrollController.dispose();
    _scrollAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(timelineProvider);
    final timelineNotifier = ref.read(timelineProvider.notifier);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            timelineNotifier.setPlaying(!timeline.isPlaying);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: kBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderColor.withOpacity(0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              TimelineToolbar(
                currentPosition: widget.currentPosition,
                onSplitClip: () {
                  // Implement split clip
                },
                onTrimClip: () {
                  // Implement trim clip
                },
                onDeleteSelected: () {
                  timelineNotifier.deleteSelectedSegments();
                },
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final timelineWidth = constraints.maxWidth * timeline.zoom;
                    final pixelsPerSecond = timelineWidth / widget.videoDuration.inSeconds;

                    return Container(
                      color: kBackgroundColor,
                      child: Stack(
                        children: [
                          GestureDetector(
                            onHorizontalDragStart: (details) => _handleTimelineDragStart(details, constraints),
                            onHorizontalDragUpdate: (details) => _handleTimelineDragUpdate(details, constraints),
                            onHorizontalDragEnd: (details) => _handleTimelineDragEnd(details, constraints),
                            onTapDown: (details) {
                              final RenderBox renderBox = context.findRenderObject() as RenderBox;
                              final localPosition = renderBox.globalToLocal(details.globalPosition);
                              _seekToPosition(localPosition.dx, timelineWidth, constraints);
                            },
                            child: Scrollbar(
                              controller: _scrollController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: SizedBox(
                                  width: timelineWidth,
                                  height: 160,  // Fixed height
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Timeline background
                                      Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: kSurfaceColor,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: kBorderColor.withOpacity(0.5),
                                                  width: 1,
                                                ),
                                              ),
                                          child: Column(
                                            children: [
                                              // Top timeline area for playhead interaction
                                              Container(
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1A1A1A),  // Darker background
                                                  border: const Border(
                                                    bottom: BorderSide(
                                                      color: Color(0xFF2A2A2A),  // Slightly lighter border
                                                      width: 1,
                                                    ),
                                                  ),
                                                  gradient: const LinearGradient(  // Subtle gradient
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Color(0xFF1A1A1A),
                                                      Color(0xFF1D1D1D),
                                                    ],
                                                  ),
                                                  boxShadow: [  // Inner shadow effect
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.3),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                                child: Stack(
                                                  children: [
                                                    // Grid overlay for extra coolness
                                                    Positioned.fill(
                                                      child: CustomPaint(
                                                        painter: TimelineGridOverlayPainter(
                                                          secondWidth: pixelsPerSecond,
                                                          zoom: timeline.zoom,
                                                        ),
                                                      ),
                                                    ),
                                                    // Ruler with timestamps
                                                    CustomPaint(
                                                      size: Size(timelineWidth, 48),
                                                      painter: TimelineRulerPainter(
                                                        secondWidth: pixelsPerSecond,
                                                        duration: widget.videoDuration,
                                                        zoom: timeline.zoom,
                                                        isScrolling: _isScrolling,
                                                        showTimestamps: true,
                                                        height: 48,
                                                      ),
                                                    ),
                                                    // Edge gradients
                                                    Positioned(
                                                      left: 0,
                                                      top: 0,
                                                      bottom: 0,
                                                      width: 32,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            begin: Alignment.centerLeft,
                                                            end: Alignment.centerRight,
                                                            colors: [
                                                              const Color(0xFF1A1A1A),
                                                              const Color(0xFF1A1A1A).withOpacity(0.0),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      right: 0,
                                                      top: 0,
                                                      bottom: 0,
                                                      width: 32,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            begin: Alignment.centerRight,
                                                            end: Alignment.centerLeft,
                                                            colors: [
                                                              const Color(0xFF1A1A1A),
                                                              const Color(0xFF1A1A1A).withOpacity(0.0),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Main timeline grid
                                              Expanded(
                                                child: GestureDetector(
                                                  behavior: HitTestBehavior.opaque,  // Ensure clicks are detected even on transparent areas
                                                  onTapDown: (details) {
                                                    timelineNotifier.clearSelection();
                                                    final position = details.localPosition.dx;
                                                    final time = (position / timelineWidth * widget.videoDuration.inMilliseconds).round();
                                                    widget.onSeek(Duration(milliseconds: time));
                                                  },
                                                  child: CustomPaint(
                                                    size: Size(timelineWidth, 160),
                                                    painter: TimelineGridPainter(
                                                      secondWidth: pixelsPerSecond,
                                                      duration: widget.videoDuration,
                                                      zoom: timeline.zoom,
                                                      isScrolling: _isScrolling,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Main clips
                                                    ...timeline.segments
                                                        .where((segment) => segment.properties['isMainClip'] == true)
                                                        .map((mainClip) {
                                                      final left = (mainClip.startTime / widget.videoDuration.inMilliseconds) * timelineWidth;
                                                      final width = ((mainClip.endTime - mainClip.startTime) / widget.videoDuration.inMilliseconds) * timelineWidth;
                                                      return Positioned(
                                                        left: left,
                                                        top: 8,
                                                        bottom: 8,
                                                        width: width,
                                                        child: TimelineClip(
                                                          segment: mainClip,
                                                          timelineWidth: timelineWidth,
                                                          thumbnails: _thumbnails,
                                                          onSeek: widget.onSeek,
                                                        ),
                                                      );
                                      }),
                                      // Layer tracks
                                      ...timeline.segments
                                          .where((segment) => segment.isLayer)
                                          .map((layer) {
                                        final left = (layer.startTime / widget.videoDuration.inMilliseconds) * timelineWidth;
                                        final width = ((layer.endTime - layer.startTime) / widget.videoDuration.inMilliseconds) * timelineWidth;
                                        
                                        final trackOffset = layer.properties['trackOffset'] as int? ?? 0;
                                        const baseHeight = 48.0;  // Base layer height
                                        const layerHeight = baseHeight;
                                        const spacing = 4.0;  // Space between layers
                                        const topTimelineHeight = 48.0;  // Height of the top timeline area
                                        final top = topTimelineHeight + 8.0 + (trackOffset * (layerHeight + spacing));  // Add topTimelineHeight to push layers down
                                        
                                        return Positioned(
                                          left: left,
                                          top: top,
                                          height: layerHeight,
                                          width: width,
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.move,
                                            child: GestureDetector(
                                              onTap: () {
                                                // Move playhead to layer start and select the layer
                                                widget.onSeek(Duration(milliseconds: layer.startTime));
                                                timelineNotifier.selectSegment(layer);
                                              },
                                              onHorizontalDragStart: (details) {
                                                timelineNotifier.selectSegment(layer);
                                              },
                                              onHorizontalDragUpdate: (details) {
                                                final pixelDelta = details.delta.dx;
                                                final timeDelta = (pixelDelta / timelineWidth * widget.videoDuration.inMilliseconds).round() * 8;
                                                final newStartTime = layer.startTime + timeDelta;
                                                final duration = layer.endTime - layer.startTime;
                                                
                                                // Only prevent going before 0
                                                if (newStartTime >= 0) {
                                                  timelineNotifier.updateSegment(
                                                    layer,
                                                    layer.copyWith(
                                                      startTime: newStartTime,
                                                      endTime: newStartTime + duration,
                                                    ),
                                                  );
                                                }
                                              },
                                              child: Stack(
                                                children: [
                                                  // Main layer content
                                                  Container(
                                                    margin: const EdgeInsets.symmetric(vertical: 2),
                                                    width: double.infinity,
                                                    height: layerHeight - 4,  // Account for margin
                                                    child: AnimatedContainer(
                                                      duration: const Duration(milliseconds: 200),
                                                      curve: Curves.easeInOut,
                                                      decoration: BoxDecoration(
                                                        color: layer.layerType == LayerType.zoom 
                                                          ? (timeline.selectedSegments.contains(layer.properties['id'])
                                                              ? const Color(0xFF2E7D32).withOpacity(0.15)
                                                              : const Color(0xFF1B5E20).withOpacity(0.08))
                                                          : (timeline.selectedSegments.contains(layer.properties['id'])
                                                              ? const Color(0xFFD32F2F).withOpacity(0.15)
                                                              : const Color(0xFFB71C1C).withOpacity(0.08)),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(
                                                          color: layer.layerType == LayerType.zoom
                                                              ? (timeline.selectedSegments.contains(layer.properties['id'])
                                                                  ? const Color(0xFF4CAF50).withOpacity(0.8)
                                                                  : const Color(0xFF2E7D32).withOpacity(0.3))
                                                              : (timeline.selectedSegments.contains(layer.properties['id'])
                                                                  ? const Color(0xFFEF5350).withOpacity(0.8)
                                                                  : const Color(0xFFD32F2F).withOpacity(0.3)),
                                                          width: timeline.selectedSegments.contains(layer.properties['id']) ? 1.5 : 1,
                                                        ),
                                                        boxShadow: timeline.selectedSegments.contains(layer.properties['id'])
                                                          ? [
                                                              BoxShadow(
                                                                color: layer.layerType == LayerType.zoom
                                                                  ? const Color(0xFF4CAF50).withOpacity(0.2)
                                                                  : const Color(0xFFEF5350).withOpacity(0.2),
                                                                blurRadius: 6,
                                                                spreadRadius: 0,
                                                              ),
                                                            ]
                                                          : null,
                                                      ),
                                                      child: (layer.endTime - layer.startTime) < 900 
                                                        ? const SizedBox.shrink()  // Show nothing for short layers
                                                        : Row(
                                                            mainAxisSize: MainAxisSize.max,
                                                            children: [
                                                              LayoutBuilder(
                                                                builder: (context, constraints) {
                                                                  final iconSize = math.min(20.0, layerHeight * 0.4);
                                                                  final fontSize = math.min(14.0, layerHeight * 0.3);
                                                                  
                                                                  // For medium layers (< 140px), show icon only
                                                                  if (constraints.maxWidth < 140) {
                                                                    return Padding(
                                                                      padding: const EdgeInsets.only(left: 8),
                                                                      child: Icon(
                                                                        layer.layerType == LayerType.zoom 
                                                                          ? Icons.zoom_in_rounded
                                                                          : Icons.content_cut_rounded,
                                                                        size: iconSize,
                                                                        color: layer.layerType == LayerType.zoom
                                                                          ? (timeline.selectedSegments.contains(layer.properties['id'])
                                                                              ? const Color(0xFF4CAF50).withOpacity(0.9)
                                                                              : const Color(0xFF2E7D32).withOpacity(0.7))
                                                                          : (timeline.selectedSegments.contains(layer.properties['id'])
                                                                              ? const Color(0xFFEF5350).withOpacity(0.9)
                                                                              : const Color(0xFFD32F2F).withOpacity(0.7)),
                                                                      ),
                                                                    );
                                                                  }
                                                                  
                                                                  // Full content for wider layers
                                                                  return Padding(
                                                                    padding: const EdgeInsets.only(left: 32),
                                                                    child: Row(
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      children: [
                                                                        Icon(
                                                                          layer.layerType == LayerType.zoom 
                                                                            ? Icons.zoom_in_rounded
                                                                            : Icons.content_cut_rounded,
                                                                          size: iconSize,
                                                                          color: layer.layerType == LayerType.zoom
                                                                            ? (timeline.selectedSegments.contains(layer.properties['id'])
                                                                                ? const Color(0xFF4CAF50).withOpacity(0.9)
                                                                                : const Color(0xFF2E7D32).withOpacity(0.7))
                                                                            : (timeline.selectedSegments.contains(layer.properties['id'])
                                                                                ? const Color(0xFFEF5350).withOpacity(0.9)
                                                                                : const Color(0xFFD32F2F).withOpacity(0.7)),
                                                                        ),
                                                                        const SizedBox(width: 8),
                                                                        Text(
                                                                          layer.layerType == LayerType.zoom ? 'Zoom' : 'Trim',
                                                                          style: TextStyle(
                                                                            color: layer.layerType == LayerType.zoom
                                                                              ? const Color(0xFF2E7D32)
                                                                              : const Color(0xFFD32F2F),
                                                                            fontSize: fontSize,
                                                                            fontWeight: FontWeight.w600,
                                                                            letterSpacing: 0.4,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  );
                                                                },
                                                              ),
                                                              const Spacer(),
                                                              if (width > 180) ...[  // Only show duration for wider layers
                                                                Text(
                                                                  '${((layer.endTime - layer.startTime) / 1000).toStringAsFixed(1)}s',
                                                                  style: TextStyle(
                                                                    color: layer.layerType == LayerType.zoom
                                                                      ? const Color(0xFF2E7D32).withOpacity(0.8)
                                                                      : const Color(0xFFD32F2F).withOpacity(0.8),
                                                                    fontSize: 13,
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 32),  // Right padding for resize handle
                                                              ],
                                                            ],
                                                          ),
                                                    ),
                                                  ),
                                                  // Left resize handle
                                                  Positioned(
                                                    left: 0,
                                                    top: 0,
                                                    bottom: 0,
                                                    child: MouseRegion(
                                                      cursor: SystemMouseCursors.resizeLeft,
                                                      child: GestureDetector(
                                                        onHorizontalDragUpdate: (details) {
                                                          final pixelDelta = details.delta.dx;
                                                          final timeDelta = (pixelDelta / timelineWidth * widget.videoDuration.inMilliseconds).round() * 8;
                                                          final newStartTime = layer.startTime + timeDelta;
                                                          
                                                          // Only prevent negative time and minimum duration
                                                          if (newStartTime >= 0 && layer.endTime - newStartTime >= 100) {
                                                            timelineNotifier.updateSegment(
                                                              layer,
                                                              layer.copyWith(startTime: newStartTime),
                                                            );
                                                          }
                                                        },
                                                        child: Container(
                                                          width: width < 60 ? 8 : width < 80 ? 12 : 16,  // Even smaller handle for tiny layers
                                                          color: Colors.transparent,
                                                          child: Center(
                                                            child: Container(
                                                              width: width < 60 ? 1.5 : width < 80 ? 2 : 3,  // Thinner line for tiny layers
                                                              height: width < 60 ? 20 : width < 80 ? 24 : 32,  // Shorter line for tiny layers
                                                              decoration: BoxDecoration(
                                                                color: layer.layerType == LayerType.zoom
                                                                  ? const Color(0xFF2E7D32).withOpacity(0.8)
                                                                  : const Color(0xFFD32F2F).withOpacity(0.8),
                                                                borderRadius: BorderRadius.circular(1),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Right resize handle
                                                  Positioned(
                                                    right: 0,
                                                    top: 0,
                                                    bottom: 0,
                                                    child: MouseRegion(
                                                      cursor: SystemMouseCursors.resizeRight,
                                                      child: GestureDetector(
                                                        onHorizontalDragUpdate: (details) {
                                                          final pixelDelta = details.delta.dx;
                                                          final timeDelta = (pixelDelta / timelineWidth * widget.videoDuration.inMilliseconds).round() * 8;
                                                          final newEndTime = layer.endTime + timeDelta;
                                                          
                                                          // Only prevent minimum duration
                                                          if (newEndTime - layer.startTime >= 100) {
                                                            timelineNotifier.updateSegment(
                                                              layer,
                                                              layer.copyWith(endTime: newEndTime),
                                                            );
                                                          }
                                                        },
                                                        child: Container(
                                                          width: width < 60 ? 8 : width < 80 ? 12 : 16,  // Even smaller handle for tiny layers
                                                          color: Colors.transparent,
                                                          child: Center(
                                                            child: Container(
                                                              width: width < 60 ? 1.5 : width < 80 ? 2 : 3,  // Thinner line for tiny layers
                                                              height: width < 60 ? 20 : width < 80 ? 24 : 32,  // Shorter line for tiny layers
                                                              decoration: BoxDecoration(
                                                                color: layer.layerType == LayerType.zoom
                                                                  ? const Color(0xFF2E7D32).withOpacity(0.8)
                                                                  : const Color(0xFFD32F2F).withOpacity(0.8),
                                                                borderRadius: BorderRadius.circular(1),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                                    if (_timelineDragPosition != null)
                                                      TimelinePlayhead(
                                                        position: _timelineDragPosition!,
                                                        isDragging: true,
                                                        isMoving: _isMovingPlayhead,
                                                        onDragUpdate: (_) {},
                                                        onDragEnd: (_) {},
                                                      ),
                                                    if (!_isDraggingPlayhead)
                                                      TimelinePlayhead(
                                                        position: (widget.currentPosition.inMilliseconds / widget.videoDuration.inMilliseconds) * timelineWidth,
                                                        isDragging: false,
                                                        isMoving: _isMovingPlayhead,
                                                        onDragUpdate: (visualPosition) {
                                                          setState(() {
                                                            _isDraggingPlayhead = true;
                                                            _timelineDragPosition = visualPosition;
                                                          });
                                                        },
                                                        onDragEnd: (visualPosition) => _handlePlayheadDragEnd(visualPosition, constraints),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 