import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/timeline_provider.dart';
import '../../constants/timeline_colors.dart';
import '../painters/timeline_grid_painter.dart';
import '../painters/timeline_ruler_painter.dart';
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
  bool _isDragging = false;
  bool _isDraggingPlayhead = false;
  List<ui.Image>? _thumbnails;
  bool _isGeneratingThumbnails = false;
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
                                  height: constraints.maxHeight,
                                  child: Stack(
                                    children: [
                                      Column(
                                        children: [
                                          Container(
                                            height: 32,
                                            margin: const EdgeInsets.only(bottom: 4),
                                            decoration: BoxDecoration(
                                              color: kSurfaceColor.withOpacity(0.5),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: CustomPaint(
                                              size: Size(timelineWidth, 32),
                                              painter: TimelineRulerPainter(
                                                secondWidth: pixelsPerSecond,
                                                duration: widget.videoDuration,
                                                zoom: timeline.zoom,
                                                isScrolling: _isScrolling,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Container(
                                              margin: const EdgeInsets.symmetric(vertical: 4),
                                              decoration: BoxDecoration(
                                                color: kSurfaceColor,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: kBorderColor.withOpacity(0.5),
                                                  width: 1,
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    CustomPaint(
                                                      size: Size(timelineWidth, constraints.maxHeight),
                                                      painter: TimelineGridPainter(
                                                        secondWidth: pixelsPerSecond,
                                                        duration: widget.videoDuration,
                                                        zoom: timeline.zoom,
                                                        isScrolling: _isScrolling,
                                                      ),
                                                    ),
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
                                        ],
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