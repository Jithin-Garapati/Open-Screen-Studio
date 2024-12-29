import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/timeline_segment.dart';
import '../providers/timeline_provider.dart';

const kBackgroundColor = Color(0xFF1A1A1A);
const kSurfaceColor = Color(0xFF2A2A2A);
const kAccentColor = Color(0xFF007AFF);
const kBorderColor = Color(0xFF3A3A3A);
const kTextColor = Color(0xFFE0E0E0);
const kTextSecondaryColor = Color(0xFF9E9E9E);

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

class _TimelineEditorState extends ConsumerState<TimelineEditor> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isDragging = false;
  bool _isDraggingPlayhead = false;
  final bool _isDraggingClipStart = false;
  final bool _isDraggingClipEnd = false;
  List<ui.Image>? _thumbnails;
  bool _isGeneratingThumbnails = false;
  final Duration _lastPosition = Duration.zero;
  Duration _clipStartTime = Duration.zero;
  Duration _clipEndTime = Duration.zero;
  Player? _thumbnailPlayer;
  bool _isInitialized = false;
  double _dragPosition = 0;
  final bool _isDraggingSegment = false;
  TimelineSegment? _draggedSegment;
  final double _segmentDragStart = 0;
  final double _segmentStartOffset = 0;
  late final ValueNotifier<Duration> _playheadPositionNotifier;

  @override
  void initState() {
    super.initState();
    _clipEndTime = widget.videoDuration;
    _playheadPositionNotifier = ValueNotifier(Duration.zero);
    _initThumbnailPlayer();
    // Add initial main clip with a delay to ensure proper initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addMainClip();
    });
  }

  Future<void> _initThumbnailPlayer() async {
    _thumbnailPlayer = Player();
    await _thumbnailPlayer!.open(Media(widget.videoPath));
    setState(() => _isInitialized = true);
    _generateThumbnails();
  }

  @override
  void didUpdateWidget(TimelineEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPosition != oldWidget.currentPosition) {
      _playheadPositionNotifier.value = widget.currentPosition;
    }
  }

  Future<void> _generateThumbnails() async {
    if (_isGeneratingThumbnails || !_isInitialized) return;
    _isGeneratingThumbnails = true;

    try {
      final thumbnails = <ui.Image>[];
      final duration = widget.videoDuration.inMilliseconds;
      const thumbnailCount = 100;
      final interval = duration ~/ thumbnailCount;

      // First generate thumbnails at key points
      final keyPoints = [
        0, // Start
        duration ~/ 4, // 25%
        duration ~/ 2, // 50%
        (duration * 3) ~/ 4, // 75%
        duration - 1, // End
      ];

      for (final timestamp in keyPoints) {
        if (!mounted) return;
        final position = Duration(milliseconds: timestamp);
        await _thumbnailPlayer!.seek(position);
        await Future.delayed(const Duration(milliseconds: 30));
        
        final frame = await _thumbnailPlayer!.screenshot();
        if (frame != null) {
          final codec = await ui.instantiateImageCodec(
            frame,
            targetHeight: 40,
            targetWidth: 71,
          );
          final frameImage = await codec.getNextFrame();
          thumbnails.add(frameImage.image);
          
          if (mounted) {
            setState(() {
              _thumbnails = List.from(thumbnails);
            });
          }
        }
      }

      // Then fill in the gaps
      for (var i = 0; i < thumbnailCount; i++) {
        if (!mounted) return;
        final timestamp = i * interval;
        if (keyPoints.contains(timestamp)) continue;

        final position = Duration(milliseconds: timestamp);
        await _thumbnailPlayer!.seek(position);
        await Future.delayed(const Duration(milliseconds: 30));
        
        final frame = await _thumbnailPlayer!.screenshot();
        if (frame != null) {
          final codec = await ui.instantiateImageCodec(
            frame,
            targetHeight: 40,
            targetWidth: 71,
          );
          final frameImage = await codec.getNextFrame();
          
          // Insert the thumbnail in the correct position
          final insertIndex = thumbnails.indexWhere((t) => 
            thumbnails.indexOf(t) * interval > timestamp
          );
          if (insertIndex == -1) {
            thumbnails.add(frameImage.image);
          } else {
            thumbnails.insert(insertIndex, frameImage.image);
          }

          if (mounted && thumbnails.length % 5 == 0) { // Update UI every 5 thumbnails
            setState(() {
              _thumbnails = List.from(thumbnails);
            });
          }
        }
      }

      if (mounted) {
        setState(() => _thumbnails = thumbnails);
      }
    } finally {
      _isGeneratingThumbnails = false;
    }
  }

  void _handleTimelineSeek(DragUpdateDetails details, BoxConstraints constraints) {
    final timelineWidth = constraints.maxWidth;
    final pixelsPerSecond = timelineWidth / widget.videoDuration.inSeconds;
    final scrollOffset = _scrollController.offset;
    
    final seekPosition = (details.localPosition.dx + scrollOffset) / pixelsPerSecond;
    // Only update video position after drag ends
    _dragPosition = details.localPosition.dx + scrollOffset;
    setState(() {});
  }

  void _handleTimelineClick(TapUpDetails details, BoxConstraints constraints) {
    if (_isDragging) return;
    
    final timelineWidth = constraints.maxWidth;
    final pixelsPerSecond = timelineWidth / widget.videoDuration.inSeconds;
    final scrollOffset = _scrollController.offset;
    
    final seekPosition = (details.localPosition.dx + scrollOffset) / pixelsPerSecond;
    widget.onSeek(Duration(milliseconds: (seekPosition * 1000).round()));
  }

  void _handlePlayheadDrag(double dx) {
    if (!_scrollController.hasClients) return;

    final scrollOffset = _scrollController.offset;
    final timelineWidth = _scrollController.position.maxScrollExtent + 
                         _scrollController.position.viewportDimension;
    
    // Just update the visual position without seeking
    final rawPosition = dx + scrollOffset;
    final clampedPosition = rawPosition.clamp(0.0, timelineWidth);
    
    setState(() {
      _isDraggingPlayhead = true;
      _dragPosition = clampedPosition;
    });
  }

  void _finishPlayheadDrag() {
    if (!_isDraggingPlayhead || !_scrollController.hasClients) return;
    
    final timelineWidth = _scrollController.position.maxScrollExtent + 
                         _scrollController.position.viewportDimension;
    final pixelsPerSecond = timelineWidth / widget.videoDuration.inSeconds;
    final seekPosition = _dragPosition / pixelsPerSecond;
    
    setState(() => _isDraggingPlayhead = false);
    
    // Update video position only after drag is complete
    final newPosition = Duration(milliseconds: (seekPosition * 1000).round());
    _playheadPositionNotifier.value = newPosition;
    widget.onSeek(newPosition);
  }

  void _handleClipHandleDrag(double dx, BoxConstraints constraints, bool isStart) {
    final timelineWidth = constraints.maxWidth;
    final position = dx.clamp(0.0, timelineWidth);
    final percentage = position / timelineWidth;
    final time = Duration(milliseconds: (percentage * widget.videoDuration.inMilliseconds).round());
    
    setState(() {
      if (isStart) {
        if (time < _clipEndTime) {
          _clipStartTime = time;
        }
      } else {
        if (time > _clipStartTime) {
          _clipEndTime = time;
        }
      }
    });
  }

  @override
  void dispose() {
    _playheadPositionNotifier.dispose();
    _thumbnailPlayer?.dispose();
    _scrollController.dispose();
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
          // Play/Pause
          if (event.logicalKey == LogicalKeyboardKey.space) {
            timelineNotifier.setPlaying(!timeline.isPlaying);
            return KeyEventResult.handled;
          }
          
          // Selection with Shift
          if (HardwareKeyboard.instance.isShiftPressed && _draggedSegment != null) {
            timelineNotifier.selectSegment(_draggedSegment!, addToSelection: true);
            return KeyEventResult.handled;
          }

          if (HardwareKeyboard.instance.isControlPressed) {
            // Undo/Redo
            if (event.logicalKey == LogicalKeyboardKey.keyZ) {
              if (HardwareKeyboard.instance.isShiftPressed) {
                timelineNotifier.redo();
              } else {
                timelineNotifier.undo();
              }
              return KeyEventResult.handled;
            }
            
            // Redo with Ctrl+Y
            if (event.logicalKey == LogicalKeyboardKey.keyY) {
              timelineNotifier.redo();
              return KeyEventResult.handled;
            }

            // Group/Ungroup
            if (event.logicalKey == LogicalKeyboardKey.keyG) {
              if (HardwareKeyboard.instance.isShiftPressed) {
                timelineNotifier.ungroupSelectedSegments();
              } else {
                timelineNotifier.groupSelectedSegments();
              }
              return KeyEventResult.handled;
            }

            // Copy/Paste
            if (event.logicalKey == LogicalKeyboardKey.keyD) {
              timelineNotifier.duplicateSelectedSegments();
              return KeyEventResult.handled;
            }

            // Select All
            if (event.logicalKey == LogicalKeyboardKey.keyA) {
              for (final segment in timeline.segments) {
                timelineNotifier.selectSegment(segment, addToSelection: true);
              }
              return KeyEventResult.handled;
            }
          }

          // Delete selected
          if (event.logicalKey == LogicalKeyboardKey.delete || 
              event.logicalKey == LogicalKeyboardKey.backspace) {
            timelineNotifier.deleteSelectedSegments();
            return KeyEventResult.handled;
          }

          // Escape to clear selection
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            timelineNotifier.clearSelection();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          // Handle keyboard shortcuts
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.space) {
              timelineNotifier.setPlaying(!timeline.isPlaying);
            } else if (HardwareKeyboard.instance.isControlPressed) {
              if (event.logicalKey == LogicalKeyboardKey.keyZ) {
                if (HardwareKeyboard.instance.isShiftPressed) {
                  timelineNotifier.redo();
                } else {
                  timelineNotifier.undo();
                }
              } else if (event.logicalKey == LogicalKeyboardKey.keyY) {
                timelineNotifier.redo();
              } else if (event.logicalKey == LogicalKeyboardKey.delete) {
                if (_draggedSegment != null) {
                  timelineNotifier.removeSegment(_draggedSegment!);
                  _draggedSegment = null;
                }
              }
            }
          }
        },
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: kBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              children: [
                _buildToolbar(timeline, timelineNotifier),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return _buildTimelineContent(constraints, timeline);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineContent(BoxConstraints constraints, TimelineState timeline) {
    return LayoutBuilder(
      builder: (context, contentConstraints) {
        final timelineWidth = contentConstraints.maxWidth * timeline.zoom;
        final pixelsPerSecond = timelineWidth / widget.videoDuration.inSeconds;

        return Container(
          color: kBackgroundColor,
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: timelineWidth,
                  height: contentConstraints.maxHeight,
                  child: Column(
                    children: [
                      // Time ruler
                      SizedBox(
                        height: 32,
                        child: CustomPaint(
                          size: Size(timelineWidth, 32),
                          painter: TimelineRulerPainter(
                            secondWidth: pixelsPerSecond,
                            duration: widget.videoDuration,
                            zoom: timeline.zoom,
                          ),
                        ),
                      ),
                      // Main clip track
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: kSurfaceColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: kBorderColor),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Grid lines
                              CustomPaint(
                                size: Size(timelineWidth, contentConstraints.maxHeight),
                                painter: TimelineGridPainter(
                                  secondWidth: pixelsPerSecond,
                                  duration: widget.videoDuration,
                                  zoom: timeline.zoom,
                                ),
                              ),
                              // Main clip from timeline provider
                              ...timeline.segments.where((segment) => 
                                segment.properties['isMainClip'] == true
                              ).map((mainClip) {
                                final left = (mainClip.startTime / widget.videoDuration.inMilliseconds) * timelineWidth;
                                final width = ((mainClip.endTime - mainClip.startTime) / widget.videoDuration.inMilliseconds) * timelineWidth;
                                return Positioned(
                                  left: left,
                                  top: 8,
                                  bottom: 8,
                                  width: width,
                                  child: _buildMainClipWidget(mainClip, timelineWidth),
                                );
                              }),
                              // Playhead
                              _buildPlayhead(
                                (widget.currentPosition.inMilliseconds / widget.videoDuration.inMilliseconds) * timelineWidth
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainClipWidget(TimelineSegment mainClip, double timelineWidth) {
    return GestureDetector(
      onHorizontalDragStart: (details) {
        setState(() {
          _isDragging = true;
          _dragPosition = details.localPosition.dx;
        });
      },
      onHorizontalDragUpdate: (details) {
        if (!_isDragging) return;
        
        final delta = details.localPosition.dx - _dragPosition;
        final timelineDelta = (delta / timelineWidth) * widget.videoDuration.inMilliseconds;
        
        final newStartTime = mainClip.startTime + timelineDelta.round();
        final clipDuration = mainClip.endTime - mainClip.startTime;
        
        if (newStartTime >= 0 && 
            newStartTime + clipDuration <= widget.videoDuration.inMilliseconds) {
          final timelineNotifier = ref.read(timelineProvider.notifier);
          final updatedClip = mainClip.copyWith(
            startTime: newStartTime,
            endTime: newStartTime + clipDuration,
          );
          timelineNotifier.updateSegment(mainClip, updatedClip);
          // Update video position when dragging clip
          widget.onSeek(Duration(milliseconds: newStartTime));
        }
      },
      onHorizontalDragEnd: (_) {
        setState(() => _isDragging = false);
      },
      child: Container(
        height: 80, // Fixed height for better visibility
        decoration: BoxDecoration(
          color: kAccentColor.withOpacity(0.2),
          border: Border.all(color: kAccentColor.withOpacity(0.8), width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            // Thumbnails
            if (_thumbnails != null)
              Row(
                children: _thumbnails!.asMap().entries.map((entry) {
                  return Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.black12),
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
                  'Main Clip',
                  style: TextStyle(
                    color: kTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            // Left trim handle
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: _buildTrimHandle(mainClip, true),
            ),
            // Right trim handle
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: _buildTrimHandle(mainClip, false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrimHandle(TimelineSegment mainClip, bool isStart) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          final renderBox = context.findRenderObject() as RenderBox;
          final localPosition = renderBox.globalToLocal(details.globalPosition);
          final timelineWidth = renderBox.size.width;
          
          final percentage = localPosition.dx / timelineWidth;
          final time = (percentage * widget.videoDuration.inMilliseconds).round();
          
          final timelineNotifier = ref.read(timelineProvider.notifier);
          final updatedClip = isStart
              ? mainClip.copyWith(startTime: time < mainClip.endTime ? time : mainClip.startTime)
              : mainClip.copyWith(endTime: time > mainClip.startTime ? time : mainClip.endTime);
          
          if (updatedClip.isValid) {
            timelineNotifier.updateSegment(mainClip, updatedClip);
          }
        },
        child: Container(
          width: 12,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: kAccentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayhead(double position) {
    return Positioned(
      left: position - 1,
      top: 0,
      bottom: 0,
      child: MouseRegion(
        cursor: _isDraggingPlayhead ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        child: GestureDetector(
          onHorizontalDragStart: (details) {
            setState(() {
              _isDraggingPlayhead = true;
              _dragPosition = position;
            });
          },
          onHorizontalDragUpdate: (details) {
            final box = context.findRenderObject() as RenderBox;
            final localPosition = box.globalToLocal(details.globalPosition);
            _handlePlayheadDrag(localPosition.dx);
          },
          onHorizontalDragEnd: (_) => _finishPlayheadDrag(),
          child: Container(
            width: 2,
            decoration: BoxDecoration(
              color: _isDraggingPlayhead ? kAccentColor : kAccentColor.withOpacity(0.9),
              boxShadow: [
                BoxShadow(
                  color: kAccentColor.withOpacity(_isDraggingPlayhead ? 0.4 : 0.2),
                  blurRadius: _isDraggingPlayhead ? 8 : 6,
                  spreadRadius: _isDraggingPlayhead ? 2 : 1,
                ),
              ],
            ),
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

  void _showSegmentContextMenu(BuildContext context, TimelineSegment segment, Offset position) {
    final timelineNotifier = ref.read(timelineProvider.notifier);
    final timeline = ref.read(timelineProvider);
    final isGroup = segment.properties['isGroup'] == true;
    
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        if (!isGroup) ...[
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.content_cut, size: 20),
                SizedBox(width: 8),
                Text('Split at Playhead'),
              ],
            ),
            onTap: () {
              timelineNotifier.splitSegmentAtTime(timeline.currentTime.inMilliseconds);
            },
          ),
          if (_canMergeWithNext(segment))
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.merge_type, size: 20),
                  SizedBox(width: 8),
                  Text('Merge with Next'),
                ],
              ),
              onTap: () {
                final nextSegment = _getNextSegment(segment);
                if (nextSegment != null) {
                  timelineNotifier.mergeSegments(segment, nextSegment);
                }
              },
            ),
        ],
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.copy, size: 20),
              SizedBox(width: 8),
              Text('Duplicate'),
            ],
          ),
          onTap: () {
            timelineNotifier.selectSegment(segment);
            timelineNotifier.duplicateSelectedSegments();
          },
        ),
        if (isGroup)
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.unfold_more, size: 20),
                SizedBox(width: 8),
                Text('Ungroup'),
              ],
            ),
            onTap: () {
              timelineNotifier.selectSegment(segment);
              timelineNotifier.ungroupSelectedSegments();
            },
          ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.delete, size: 20),
              SizedBox(width: 8),
              Text('Delete'),
            ],
          ),
          onTap: () {
            timelineNotifier.selectSegment(segment);
            timelineNotifier.deleteSelectedSegments();
          },
        ),
      ],
    );
  }

  bool _canMergeWithNext(TimelineSegment segment) {
    final nextSegment = _getNextSegment(segment);
    if (nextSegment == null) return false;
    return segment.endTime == nextSegment.startTime && segment.type == nextSegment.type;
  }

  TimelineSegment? _getNextSegment(TimelineSegment segment) {
    final segments = ref.read(timelineProvider).segments;
    final index = segments.indexOf(segment);
    if (index < segments.length - 1) {
      return segments[index + 1];
    }
    return null;
  }

  Widget _buildToolbar(TimelineState timeline, TimelineNotifier timelineNotifier) {
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
                onPressed: () {
                  // Toggle play state and notify parent
                  timelineNotifier.setPlaying(!timeline.isPlaying);
                  if (!timeline.isPlaying) {
                    widget.onSeek(widget.currentPosition);
                  }
                },
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
                  _formatDuration(widget.currentPosition),
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

  Widget _buildEditButtons() {
    return Row(
      children: [
        _buildToolbarButton(
          icon: Icons.content_cut_rounded,
          tooltip: 'Split at Playhead',
          onPressed: _splitClipAtPlayhead,
        ),
        const SizedBox(width: 8),
        _buildToolbarButton(
          icon: Icons.content_copy_rounded,
          tooltip: 'Trim to Selection',
          onPressed: _trimClip,
        ),
        const SizedBox(width: 8),
        _buildToolbarButton(
          icon: Icons.delete_rounded,
          tooltip: 'Delete Selected',
          onPressed: _deleteSelectedRange,
        ),
      ],
    );
  }

  void _splitClipAtPlayhead() {
    final currentTime = widget.currentPosition;
    if (currentTime > _clipStartTime && currentTime < _clipEndTime) {
      final timelineNotifier = ref.read(timelineProvider.notifier);
      
      // Create two segments from the split
      final firstSegment = TimelineSegment(
        startTime: _clipStartTime.inMilliseconds,
        endTime: currentTime.inMilliseconds,
        type: SegmentType.normal,
        color: kAccentColor,
      );
      
      final secondSegment = TimelineSegment(
        startTime: currentTime.inMilliseconds,
        endTime: _clipEndTime.inMilliseconds,
        type: SegmentType.normal,
        color: kAccentColor,
      );
      
      timelineNotifier.addSegment(firstSegment);
      timelineNotifier.addSegment(secondSegment);
    }
  }

  void _deleteSelectedRange() {
    final timelineNotifier = ref.read(timelineProvider.notifier);
    final selectedSegments = ref.read(timelineProvider).selectedSegments;
    
    for (final segment in selectedSegments) {
      timelineNotifier.removeSegment(segment);
    }
  }

  void _trimClip() {
    final timelineNotifier = ref.read(timelineProvider.notifier);
    
    // Create a segment for the trimmed region
    final segment = TimelineSegment(
      startTime: _clipStartTime.inMilliseconds,
      endTime: _clipEndTime.inMilliseconds,
      type: SegmentType.normal,
      color: kAccentColor,
    );
    
    timelineNotifier.addSegment(segment);
  }

  void _addMainClip() {
    final timelineNotifier = ref.read(timelineProvider.notifier);
    final mainClip = TimelineSegment(
      startTime: 0,
      endTime: widget.videoDuration.inMilliseconds,
      type: SegmentType.normal,
      color: kAccentColor,
      properties: {'isMainClip': true},
    );
    timelineNotifier.addSegment(mainClip);
  }
}

class TimelineGridPainter extends CustomPainter {
  final double secondWidth;
  final Duration duration;
  final double zoom;

  TimelineGridPainter({
    required this.secondWidth,
    required this.duration,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    final majorPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Calculate marker intervals based on zoom
    final markerInterval = _calculateMarkerInterval(zoom);
    final majorInterval = markerInterval * 5;

    // Draw vertical lines and time markers
    for (var i = 0; i <= duration.inSeconds; i++) {
      final x = i * secondWidth;
      final seconds = i;
      final isMajor = seconds % majorInterval == 0;
      final isMinor = seconds % markerInterval == 0;

      // Draw grid line
      canvas.drawLine(
        Offset(x, isMajor ? 0 : 20),
        Offset(x, size.height),
        isMajor ? majorPaint : paint,
      );

      // Draw time marker
      if (isMajor || (isMinor && zoom > 0.5)) {
        final time = Duration(seconds: seconds);
        final text = _formatDuration(time, isMajor);
        textPainter.text = TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.white.withOpacity(isMajor ? 0.8 : 0.5),
            fontSize: isMajor ? 11 : 9,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, isMajor ? 2 : 8),
        );
      }
    }

    // Draw horizontal lines
    final horizontalGap = size.height / 4;
    for (var i = 0; i <= 4; i++) {
      final y = i * horizontalGap;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  int _calculateMarkerInterval(double zoom) {
    if (zoom >= 2.0) return 1;      // 1 second
    if (zoom >= 1.0) return 5;      // 5 seconds
    if (zoom >= 0.5) return 15;     // 15 seconds
    if (zoom >= 0.25) return 30;    // 30 seconds
    return 60;                      // 1 minute
  }

  String _formatDuration(Duration duration, bool isMajor) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    if (minutes > 0) {
      return isMajor ? '$minutes:${seconds.toString().padLeft(2, '0')}' : seconds.toString();
    }
    return seconds.toString();
  }

  @override
  bool shouldRepaint(covariant TimelineGridPainter oldDelegate) {
    return oldDelegate.secondWidth != secondWidth ||
           oldDelegate.duration != duration ||
           oldDelegate.zoom != zoom;
  }
}

class WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path();
    var x = 0.0;
    final width = size.width;
    final height = size.height;
    path.moveTo(x, height / 2);

    while (x < width) {
      // Generate a simple waveform pattern
      final y = height / 2 + (height / 4) * sin(x / 20);
      path.lineTo(x, y);
      x += 1;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TimelineBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..style = PaintingStyle.fill;

    // Draw subtle gradient pattern
    for (var i = 0; i < size.width; i += 40) {
      canvas.drawRect(
        Rect.fromLTWH(i.toDouble(), 0, 20, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TimelineRulerPainter extends CustomPainter {
  final double secondWidth;
  final Duration duration;
  final double zoom;

  TimelineRulerPainter({
    required this.secondWidth,
    required this.duration,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    final majorPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Calculate marker intervals based on zoom
    final markerInterval = _calculateMarkerInterval(zoom);
    final majorInterval = markerInterval * 5;

    // Draw vertical lines and time markers
    for (var i = 0; i <= duration.inSeconds; i++) {
      final x = i * secondWidth;
      final seconds = i;
      final isMajor = seconds % majorInterval == 0;
      final isMinor = seconds % markerInterval == 0;

      if (isMajor || isMinor) {
        // Draw marker line
        canvas.drawLine(
          Offset(x, isMajor ? 0 : size.height * 0.3),
          Offset(x, size.height),
          isMajor ? majorPaint : paint,
        );

        // Draw time label
        if (isMajor || (isMinor && zoom > 0.5)) {
          final time = Duration(seconds: seconds);
          final text = _formatDuration(time, isMajor);
          textPainter.text = TextSpan(
            text: text,
            style: TextStyle(
              color: Colors.white.withOpacity(isMajor ? 0.8 : 0.5),
              fontSize: isMajor ? 11 : 9,
              fontWeight: isMajor ? FontWeight.w500 : FontWeight.normal,
            ),
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(x - textPainter.width / 2, isMajor ? 2 : 8),
          );
        }
      }
    }
  }

  int _calculateMarkerInterval(double zoom) {
    if (zoom >= 2.0) return 1;      // 1 second
    if (zoom >= 1.0) return 5;      // 5 seconds
    if (zoom >= 0.5) return 15;     // 15 seconds
    if (zoom >= 0.25) return 30;    // 30 seconds
    return 60;                      // 1 minute
  }

  String _formatDuration(Duration duration, bool isMajor) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    if (minutes > 0) {
      return isMajor ? '$minutes:${seconds.toString().padLeft(2, '0')}' : seconds.toString();
    }
    return seconds.toString();
  }

  @override
  bool shouldRepaint(covariant TimelineRulerPainter oldDelegate) {
    return oldDelegate.secondWidth != secondWidth ||
           oldDelegate.duration != duration ||
           oldDelegate.zoom != zoom;
  }
}

class TimelineMarkersPainter extends CustomPainter {
  final Duration currentTime;
  final Duration duration;
  final double zoom;

  TimelineMarkersPainter({
    required this.currentTime,
    required this.duration,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    // Draw vertical time markers
    final markerInterval = _calculateMarkerInterval(zoom);
    final totalSeconds = duration.inSeconds;

    for (var i = 0; i <= totalSeconds; i += markerInterval) {
      final x = (i / totalSeconds) * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw current time marker
    final currentX = (currentTime.inSeconds / totalSeconds) * size.width;
    final currentTimePaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(currentX, 0),
      Offset(currentX, size.height),
      currentTimePaint,
    );
  }

  int _calculateMarkerInterval(double zoom) {
    if (zoom >= 2.0) return 1;      // 1 second
    if (zoom >= 1.0) return 5;      // 5 seconds
    if (zoom >= 0.5) return 15;     // 15 seconds
    if (zoom >= 0.25) return 30;    // 30 seconds
    return 60;                      // 1 minute
  }

  @override
  bool shouldRepaint(covariant TimelineMarkersPainter oldDelegate) {
    return oldDelegate.currentTime != currentTime ||
           oldDelegate.duration != duration ||
           oldDelegate.zoom != zoom;
  }
} 