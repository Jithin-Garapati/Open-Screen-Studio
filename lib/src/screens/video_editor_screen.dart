import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:ui' as ui;
import '../config/window_config.dart';
import '../controllers/cursor_tracking_controller.dart';
import '../models/cursor_position.dart';
import '../services/cursor_tracker.dart';
import '../widgets/video_editor_panel.dart';
import '../providers/cursor_settings_provider.dart';
import '../providers/auto_zoom_provider.dart';
import '../widgets/timeline_editor.dart';
import '../services/ffmpeg_service.dart';
import '../features/timeline/providers/timeline_provider.dart';
import '../features/timeline/providers/zoom_settings_provider.dart';
import '../features/timeline/models/timeline_segment.dart';
import 'dart:async';
import 'package:flutter/rendering.dart';

enum VideoExportFormat {
  mp4_169, // 16:9
  mp4_916, // 9:16 (vertical)
  mp4_11,  // 1:1 (square)
  gif
}

class VideoEditorScreen extends ConsumerStatefulWidget {
  final String videoPath;
  const VideoEditorScreen({super.key, required this.videoPath});

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> with TickerProviderStateMixin {
  late final player = Player();
  late final controller = VideoController(player);
  CursorPosition? _currentCursor;
  Offset _currentOffset = Offset.zero;
  bool _isFullScreen = false;
  double _playbackSpeed = 1.0;
  VideoExportFormat _selectedFormat = VideoExportFormat.mp4_169;
  bool _showEditor = true;
  int _lastSeekTime = 0;
  
  // Zoom state
  double _currentScale = 1.0;
  Offset _currentTranslate = Offset.zero;

  @override
  void initState() {
    super.initState();
    setWindowForPreview();
    player.open(Media(widget.videoPath));
    
    // Separate streams for cursor updates and trim handling
    player.stream.position
      .listen((position) {
        if (!mounted) return;
        _updateCursorPosition(position.inMilliseconds);
      }, cancelOnError: false);

    // Dedicated stream for trim handling with less frequent updates
    player.stream.position
      .listen((position) {
        if (!mounted || !player.state.playing) return;
        
        final currentTimeMs = position.inMilliseconds;
        final timeline = ref.read(timelineProvider);
        
        // Get all trim layers sorted by start time
        final trimLayers = timeline.segments
            .where((segment) => segment.isLayer && segment.layerType == LayerType.trim)
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        
        if (trimLayers.isEmpty) return;
        
        // Find if we're in a trim region using binary search
        int left = 0;
        int right = trimLayers.length - 1;
        
        while (left <= right) {
          final mid = (left + right) ~/ 2;
          final layer = trimLayers[mid];
          
          if (currentTimeMs >= layer.startTime && currentTimeMs < layer.endTime) {
            // Found a trim region, calculate next valid position
            int nextValidPosition = layer.endTime + 1;
            
            // Check for consecutive trim layers
            for (int i = mid + 1; i < trimLayers.length; i++) {
              if (trimLayers[i].startTime <= nextValidPosition) {
                nextValidPosition = trimLayers[i].endTime + 1;
              } else {
                break;
              }
            }
            
            // Seek to next valid position
            if (nextValidPosition > currentTimeMs) {
              player.seek(Duration(milliseconds: nextValidPosition));
            }
            break;
          }
          
          if (layer.startTime > currentTimeMs) {
            right = mid - 1;
          } else {
            left = mid + 1;
          }
        }
      }, cancelOnError: false);
  }

  void _updateCursorPosition(int currentTimeMs) {
    final cursorState = ref.read(cursorTrackingProvider);
    if (cursorState.positions.isEmpty) return;
    
    // Interpolate between cursor positions for smoother movement
    int index = _binarySearchCursorPosition(cursorState.positions, currentTimeMs);
    if (index < 0) return;
    
    final currentPos = cursorState.positions[index];
    CursorPosition? nextPos;
    
    if (index < cursorState.positions.length - 1) {
      nextPos = cursorState.positions[index + 1];
    }
    
    if (nextPos != null && currentPos.timestamp != nextPos.timestamp) {
      // Interpolate between positions
      final progress = (currentTimeMs - currentPos.timestamp) / 
                      (nextPos.timestamp - currentPos.timestamp);
      
      if (progress >= 0 && progress <= 1) {
        final interpolatedX = currentPos.x + (nextPos.x - currentPos.x) * progress;
        final interpolatedY = currentPos.y + (nextPos.y - currentPos.y) * progress;
        
        _currentCursor = CursorPosition(
          x: interpolatedX,
          y: interpolatedY,
          timestamp: currentTimeMs,
          cursorType: currentPos.cursorType,
        );
      } else {
        _currentCursor = currentPos;
      }
    } else {
      _currentCursor = currentPos;
    }
    
    if (_currentCursor != null) {
      final isInBounds = _currentCursor!.x >= 0.0 && 
                        _currentCursor!.x <= 1.0 &&
                        _currentCursor!.y >= 0.0 && 
                        _currentCursor!.y <= 1.0;
                        
      if (mounted) {
        setState(() {
          _currentOffset = isInBounds 
              ? Offset(_currentCursor!.x, _currentCursor!.y)
              : const Offset(-1, -1);
        });
      }
    }
  }

  int _binarySearchCursorPosition(List<CursorPosition> positions, int timestamp) {
    int left = 0;
    int right = positions.length - 1;
    
    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final pos = positions[mid];
      
      if (pos.timestamp == timestamp) {
        return mid;
      }
      
      if (mid < positions.length - 1 && 
          pos.timestamp <= timestamp && 
          positions[mid + 1].timestamp > timestamp) {
        return mid;
      }
      
      if (pos.timestamp < timestamp) {
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }
    
    return right.clamp(0, positions.length - 1);
  }

  void _toggleFullScreen() async {
    setState(() => _isFullScreen = !_isFullScreen);
    if (_isFullScreen) {
      await windowManager.setFullScreen(true);
    } else {
      await windowManager.setFullScreen(false);
      await setWindowForPreview();
    }
  }

  void _setPlaybackSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    player.setRate(speed);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _exportVideo(VideoExportFormat format) async {
    final cursorState = ref.read(cursorTrackingProvider);
    final cursorSettings = ref.read(cursorSettingsProvider);
    final autoZoom = ref.read(autoZoomProvider);
    
    // Get output path
    final inputPath = widget.videoPath;
    final outputDir = path.dirname(inputPath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = path.join(
      outputDir,
      'export_${format.name}_$timestamp.mp4',
    );

    // Prepare FFmpeg arguments based on format
    final ffmpeg = ref.read(ffmpegServiceProvider);
    final aspectRatio = switch (format) {
      VideoExportFormat.mp4_169 => '16:9',
      VideoExportFormat.mp4_916 => '9:16',
      VideoExportFormat.mp4_11 => '1:1',
      VideoExportFormat.gif => '16:9',
    };

    // Build complex filter for cursor overlay
    final filters = <String>[
      // Scale video to target aspect ratio
      '[0:v]scale=${aspectRatio.split(':')[0]}*iw/${aspectRatio.split(':')[1]}:${aspectRatio.split(':')[1]}*iw/${aspectRatio.split(':')[0]}[scaled]',
    ];

    // Add cursor overlay if visible
    if (cursorSettings.isVisible && cursorState.positions.isNotEmpty) {
      // Create cursor overlay with proper scaling and opacity
      filters.add(
        '[scaled]overlay=x=${cursorState.positions.first.x}*W:y=${cursorState.positions.first.y}*H:enable=\'between(t,0,${cursorState.positions.last.timestamp/1000})\':alpha=${cursorSettings.opacity}[out]',
      );
    }

    // Build FFmpeg command
    final args = [
      '-i', inputPath,
      '-i', CursorTracker.getCursorImage(cursorState.positions.first.cursorType),
      '-filter_complex', filters.join(';'),
      '-map', '[out]',
      '-c:v', 'libx264',
      '-preset', 'medium',
      '-crf', '23',
    ];

    // For GIF output
    if (format == VideoExportFormat.gif) {
      args.addAll([
        '-f', 'gif',
        outputPath.replaceAll('.mp4', '.gif'),
      ]);
    } else {
      args.add(outputPath);
    }

    try {
      // Show progress dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Exporting video...'),
            ],
          ),
        ),
      );

      // Start FFmpeg process
      final process = await Process.start('ffmpeg', args);
      
      // Wait for completion
      final exitCode = await process.exitCode;
      
      // Close progress dialog
      if (!mounted) return;
      Navigator.of(context).pop();

      if (exitCode == 0) {
        // Show success message
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video exported successfully to: $outputPath'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open Folder',
              onPressed: () async {
                await Process.run('explorer.exe', ['/select,', outputPath]);
              },
            ),
          ),
        );
      } else {
        throw Exception('FFmpeg process failed with exit code: $exitCode');
      }
    } catch (e) {
      // Close progress dialog if open
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to check if a time is within any trim layer
  bool _isTimeInTrimRegion(int timeMs) {
    final timeline = ref.read(timelineProvider);
    return timeline.segments
        .where((segment) => segment.isLayer && segment.layerType == LayerType.trim)
        .any((layer) => timeMs >= layer.startTime && timeMs <= layer.endTime);
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final appBarHeight = _isFullScreen ? 0.0 : AppBar().preferredSize.height;
    final timelineHeight = _isFullScreen ? 0.0 : 200.0;
    final availableHeight = size.height - appBarHeight - timelineHeight;
    final cursorSettings = ref.watch(cursorSettingsProvider);
    final autoZoom = ref.watch(autoZoomProvider);
    final timeline = ref.watch(timelineProvider);
    
    // Calculate video dimensions to fit the screen while maintaining aspect ratio
    const videoAspectRatio = 16 / 9;
    final containerWidth = size.width - (_showEditor ? 300 : 0);
    final containerHeight = availableHeight;
    
    // Calculate dimensions to fit while maintaining aspect ratio
    double videoWidth;
    double videoHeight;
    if (containerWidth / containerHeight > videoAspectRatio) {
      // Width is the limiting factor
      videoHeight = containerHeight;
      videoWidth = videoHeight * videoAspectRatio;
    } else {
      // Height is the limiting factor
      videoWidth = containerWidth;
      videoHeight = videoWidth / videoAspectRatio;
    }
    
    final videoX = (containerWidth - videoWidth) / 2;
    final videoY = appBarHeight;

    // Find active zoom layer at current position
    final currentTimeMs = player.state.position.inMilliseconds;
    final activeZoomLayer = timeline.segments
        .where((segment) => 
          segment.isLayer && 
          segment.layerType == LayerType.zoom &&
          currentTimeMs >= segment.startTime &&
          currentTimeMs <= segment.endTime)
        .firstOrNull;

    // Get zoom settings if there's an active layer
    final zoomSettings = activeZoomLayer != null
        ? ref.watch(zoomSettingsProvider)[activeZoomLayer.properties['id']]
        : null;

    // Calculate zoom transition progress based on layer position
    double zoomProgress = 0.0;
    if (zoomSettings != null && activeZoomLayer != null) {
      final layerDuration = activeZoomLayer.endTime - activeZoomLayer.startTime;
      final transitionDuration = (layerDuration * 0.15).clamp(500.0, 1000.0); // 15% of layer duration
      
      if (currentTimeMs - activeZoomLayer.startTime < transitionDuration) {
        // Zoom in at start of layer
        zoomProgress = (currentTimeMs - activeZoomLayer.startTime) / transitionDuration;
        zoomProgress = Curves.easeOutCubic.transform(zoomProgress);
      } else if (activeZoomLayer.endTime - currentTimeMs < transitionDuration) {
        // Zoom out at end of layer
        zoomProgress = (activeZoomLayer.endTime - currentTimeMs) / transitionDuration;
        zoomProgress = Curves.easeInCubic.transform(zoomProgress);
      } else {
        // Stay at full zoom during layer
        zoomProgress = 1.0;
      }

      // Calculate zoom transform
      final targetScale = zoomSettings.scale;
      _currentScale = 1.0 + ((targetScale - 1.0) * zoomProgress);
      
      final targetOffset = Offset(
        (0.5 - zoomSettings.target.dx) * videoWidth,
        (0.5 - zoomSettings.target.dy) * videoHeight,
      ) * (_currentScale - 1);
      _currentTranslate = targetOffset * zoomProgress;
    } else {
      // Reset zoom when no layer is active
      _currentScale = 1.0;
      _currentTranslate = Offset.zero;
    }

    return Scaffold(
      appBar: _isFullScreen ? null : AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
        title: const Text('Video Editor'),
        actions: [
          IconButton(
            icon: Icon(
              _showEditor ? Icons.edit_off : Icons.edit,
              color: Colors.white70,
            ),
            onPressed: () => setState(() => _showEditor = !_showEditor),
          ),
          PopupMenuButton<VideoExportFormat>(
            icon: const Icon(Icons.save),
            onSelected: (format) {
              setState(() => _selectedFormat = format);
              _exportVideo(format);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: VideoExportFormat.mp4_169,
                child: Text('Export as 16:9'),
              ),
              const PopupMenuItem(
                value: VideoExportFormat.mp4_916,
                child: Text('Export as 9:16 (Vertical)'),
              ),
              const PopupMenuItem(
                value: VideoExportFormat.mp4_11,
                child: Text('Export as 1:1 (Square)'),
              ),
              const PopupMenuItem(
                value: VideoExportFormat.gif,
                child: Text('Export as GIF'),
              ),
            ],
          ),
        ],
        toolbarHeight: 48,
        flexibleSpace: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) => windowManager.startDragging(),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Video Area with Editor
          Expanded(
            child: Row(
              children: [
                // Video Area
                Expanded(
                  child: Stack(
                    children: [
                      // Video Player with zoom transform
                      Positioned(
                        left: videoX,
                        top: videoY,
                        width: videoWidth,
                        height: videoHeight,
                        child: ClipRect(
                          child: Transform(
                            transform: Matrix4.identity()
                              ..translate(
                                -_currentTranslate.dx,
                                -_currentTranslate.dy,
                              )
                              ..scale(_currentScale),
                            alignment: Alignment.center,
                            filterQuality: FilterQuality.high,
                            child: Video(
                              controller: controller,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ),
                      
                      // Cursor Overlay with improved positioning
                      if (_currentCursor != null && 
                          cursorSettings.isVisible && 
                          _currentOffset.dx >= 0 && 
                          _currentOffset.dy >= 0)
                        Positioned(
                          left: videoX + (_currentOffset.dx * videoWidth * _currentScale - _currentTranslate.dx),
                          top: videoY + (_currentOffset.dy * videoHeight * _currentScale - _currentTranslate.dy),
                          child: Transform.scale(
                            scale: cursorSettings.size,
                            child: Opacity(
                              opacity: cursorSettings.opacity,
                              child: ColorFiltered(
                                colorFilter: cursorSettings.tintColor != null
                                    ? ColorFilter.mode(
                                        cursorSettings.tintColor!,
                                        BlendMode.srcATop,
                                      )
                                    : const ColorFilter.mode(
                                        Colors.transparent,
                                        BlendMode.dst,
                                      ),
                                child: Image.asset(
                                  CursorTracker.getCursorImage(_currentCursor!.cursorType),
                                  width: 32,
                                  height: 32,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Video Controls Overlay
                      if (!_isFullScreen)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: MouseRegion(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.7),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          player.state.playing ? Icons.pause : Icons.play_arrow,
                                          color: Colors.white,
                                        ),
                                        onPressed: () {
                                          if (!player.state.playing) {
                                            // Check if we're starting playback in a trim region
                                            final timeline = ref.read(timelineProvider);
                                            final currentTimeMs = player.state.position.inMilliseconds;
                                            
                                            final trimLayers = timeline.segments
                                                .where((segment) => segment.isLayer && segment.layerType == LayerType.trim)
                                                .toList()
                                              ..sort((a, b) => a.startTime.compareTo(b.startTime));
                                            
                                            // Find if we're in a trim region
                                            for (final trimLayer in trimLayers) {
                                              if (currentTimeMs >= trimLayer.startTime && currentTimeMs < trimLayer.endTime) {
                                                // Calculate next valid position after all consecutive trim regions
                                                int nextValidPosition = trimLayer.endTime + 1;
                                                
                                                for (int i = trimLayers.indexOf(trimLayer) + 1; i < trimLayers.length; i++) {
                                                  if (trimLayers[i].startTime <= nextValidPosition) {
                                                    nextValidPosition = trimLayers[i].endTime + 1;
                                                  } else {
                                                    break;
                                                  }
                                                }
                                                
                                                // Seek to end of trim region before starting playback
                                                _lastSeekTime = nextValidPosition;
                                                player.seek(Duration(milliseconds: nextValidPosition));
                                                break;
                                              }
                                            }
                                          }
                                          player.playOrPause();
                                        },
                                      ),
                                      StreamBuilder(
                                        stream: player.stream.volume,
                                        builder: (context, snapshot) {
                                          return Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  player.state.volume == 0
                                                      ? Icons.volume_off
                                                      : Icons.volume_up,
                                                  color: Colors.white,
                                                ),
                                                onPressed: () {
                                                  player.setVolume(
                                                      player.state.volume == 0 ? 100 : 0);
                                                },
                                              ),
                                              SizedBox(
                                                width: 100,
                                                child: Slider(
                                                  value: player.state.volume,
                                                  max: 100,
                                                  onChanged: (value) {
                                                    player.setVolume(value);
                                                  },
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          autoZoom.enabled ? Icons.zoom_in : Icons.zoom_out_map,
                                          color: autoZoom.enabled ? Colors.blue : Colors.white,
                                          size: 28,
                                        ),
                                        tooltip: 'Auto Zoom',
                                        onPressed: () {
                                          ref.read(autoZoomProvider.notifier).toggleEnabled();
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      PopupMenuButton<double>(
                                        icon: const Icon(Icons.speed, color: Colors.white),
                                        onSelected: _setPlaybackSpeed,
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 0.5,
                                            child: Text('0.5x'),
                                          ),
                                          const PopupMenuItem(
                                            value: 1.0,
                                            child: Text('1.0x'),
                                          ),
                                          const PopupMenuItem(
                                            value: 1.5,
                                            child: Text('1.5x'),
                                          ),
                                          const PopupMenuItem(
                                            value: 2.0,
                                            child: Text('2.0x'),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _isFullScreen
                                              ? Icons.fullscreen_exit
                                              : Icons.fullscreen,
                                          color: Colors.white,
                                        ),
                                        onPressed: _toggleFullScreen,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Editor Panel
                if (_showEditor && !_isFullScreen)
                  VideoEditorPanel(
                    videoController: controller,
                    currentPosition: player.state.position,
                    videoSize: Size(videoWidth, videoHeight),
                  ),
              ],
            ),
          ),

          // Timeline Editor
          if (!_isFullScreen)
            TimelineEditor(
              videoDuration: player.state.duration,
              currentPosition: player.state.position,
              onSeek: (position) => player.seek(position),
              videoPath: widget.videoPath,
            ),
        ],
      ),
    );
  }
} 