import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import '../config/window_config.dart';
import '../controllers/cursor_tracking_controller.dart';
import '../models/cursor_position.dart';
import '../services/cursor_tracker.dart';
import '../providers/cursor_settings_provider.dart';
import '../providers/auto_zoom_provider.dart';
import '../widgets/timeline_editor.dart';
import '../features/timeline/providers/timeline_provider.dart';
import '../features/timeline/providers/click_positions_provider.dart';
import '../features/timeline/models/timeline_segment.dart';
import '../models/cursor_type.dart';
import 'dart:async';
import '../features/background/presentation/widgets/video_background_container.dart';
import '../features/background/presentation/widgets/background_settings_panel.dart';
import '../features/timeline/providers/timeline_zoom_settings_provider.dart';
import '../features/background/providers/background_settings_provider.dart';
import 'dart:convert';
import '../services/video_export_service.dart';

class VideoEditorScreen extends ConsumerStatefulWidget {
  final String videoPath;
  const VideoEditorScreen({super.key, required this.videoPath});

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class ExportControls extends StatelessWidget {
  final bool isExporting;
  final double playbackSpeed;
  final VoidCallback onExport;
  final ValueChanged<double> onSpeedChanged;

  const ExportControls({
    super.key,
    required this.isExporting,
    required this.playbackSpeed,
    required this.onExport,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<double>(
            value: playbackSpeed,
            dropdownColor: const Color(0xFF151515),
            style: const TextStyle(color: Colors.white),
            items: [0.5, 1.0, 1.5, 2.0].map((speed) {
              return DropdownMenuItem(
                value: speed,
                child: Text('${speed}x'),
              );
            }).toList(),
            onChanged: (speed) {
              if (speed != null) onSpeedChanged(speed);
            },
          ),
          const SizedBox(width: 16),
          MouseRegion(
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: isExporting ? null : onExport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF151515),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ).copyWith(
                  overlayColor: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.hovered)) {
                        return const Color(0xFF00E5FF).withOpacity(0.15);
                      }
                      return null;
                    },
                  ),
                ),
                icon: isExporting ? null : const Icon(Icons.save),
                label: isExporting 
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Exporting...'),
                      ],
                    )
                  : const Text('Export Video'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> with TickerProviderStateMixin {
  late final player = Player();
  late final controller = VideoController(player);
  CursorPosition? _currentCursor;
  Offset _currentOffset = Offset.zero;
  bool _isFullScreen = false;
  double _playbackSpeed = 1.0;
  final VideoExportFormat _selectedFormat = VideoExportFormat.mp4_169;
  final bool _showEditor = true;
  final int _lastSeekTime = 0;
  
  // Zoom state
  double _currentScale = 1.0;
  Offset _currentTranslate = Offset.zero;
  bool _isExporting = false;

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

        // Track cursor events
        ref.read(cursorEventsProvider.notifier).addEvent(
          Offset(interpolatedX, interpolatedY),
          currentTimeMs,
          isClick: currentPos.cursorType == CursorType.hand,
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

  Future<void> _exportVideo() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final videoName = path.basenameWithoutExtension(widget.videoPath);
      
      // Create exports directory if it doesn't exist
      final exportsDir = path.join(path.dirname(widget.videoPath), 'Exports');
      await Directory(exportsDir).create(recursive: true);
      
      // Create specific export folder for this video
      final exportFolder = path.join(exportsDir, '${videoName}_$timestamp');
      await Directory(exportFolder).create(recursive: true);
      
      // Setup export paths
      final outputPath = path.join(exportFolder, 'exported_video.mp4');
      final cursorDataPath = path.join(exportFolder, 'cursor_data.json');
      final zoomConfigPath = path.join(exportFolder, 'zoom_config.json');

      // Copy cursor data if it exists in original location
      final originalCursorPath = path.join(
        path.dirname(widget.videoPath),
        '${videoName}_cursor_data.json'
      );
      if (await File(originalCursorPath).exists()) {
        await File(originalCursorPath).copy(cursorDataPath);
      }

      // Export zoom configuration
      await _exportZoomConfig(zoomConfigPath);

      // Export video with all configurations
      await VideoExportService.exportVideo(
        inputPath: widget.videoPath,
        outputPath: outputPath,
        cursorDataPath: cursorDataPath,
        zoomConfigPath: zoomConfigPath,
        playbackSpeed: _playbackSpeed,
        format: _selectedFormat,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Export completed successfully!'),
                const SizedBox(height: 4),
                Text('Location: $exportFolder', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportZoomConfig(String configPath) async {
    // Get settings from providers
    final timelineZoomSettings = ref.read(timelineZoomSettingsProvider);
    final cursorSettings = ref.read(cursorSettingsProvider);
    final backgroundSettings = ref.read(backgroundSettingsProvider);
    final timeline = ref.read(timelineProvider);

    // Get video FPS for frame calculations
    final fps = player.state.duration.inMilliseconds > 0 
        ? (player.state.duration.inMilliseconds / 1000.0)
        : 30.0;  // Fallback to 30fps if duration is not available

    // Prepare zoom configuration matching C++ backend format
    final zoomConfig = {
      'zoom': {
        'type': 'Auto',  // or 'Manual' based on settings
        'autoLayers': timeline.segments
            .where((segment) => segment.isLayer && segment.layerType == LayerType.zoom)
            .map((layer) {
          final settings = timelineZoomSettings[layer.properties['id']];
          return {
            'startFrame': layer.startTime ~/ (1000 / fps),
            'endFrame': layer.endTime ~/ (1000 / fps),
            'minScale': 1.0,
            'maxScale': settings?.scale ?? 2.0,
            'followSpeed': 0.3,
            'smoothing': 0.7,
          };
        }).toList(),
        'manualLayers': timeline.segments
            .where((segment) => 
              segment.isLayer && 
              segment.layerType == LayerType.zoom && 
              !(timelineZoomSettings[segment.properties['id']]?.isAutoZoom ?? true))
            .map((layer) {
          final settings = timelineZoomSettings[layer.properties['id']];
          return {
            'startFrame': layer.startTime ~/ (1000 / fps),
            'endFrame': layer.endTime ~/ (1000 / fps),
            'startScale': 1.0,
            'endScale': settings?.scale ?? 2.0,
            'targetX': settings?.target.dx ?? 0.5,
            'targetY': settings?.target.dy ?? 0.5,
          };
        }).toList(),
        'defaults': {
          'defaultScale': 1.0,
          'transitionDuration': 0.5,
          'minScale': 1.0,
          'maxScale': 2.5,
          'followSpeed': 0.3,
          'smoothing': 0.7,
        }
      },
      'cursor': {
        'size': cursorSettings.size,
        'opacity': cursorSettings.opacity,
        'tintColor': cursorSettings.tintColor?.value ?? 0,
        'hasTint': cursorSettings.tintColor != null,
      },
      'background': {
        'color': backgroundSettings.color?.value ?? 0xFF000000,
        'cornerRadius': backgroundSettings.cornerRadius,
        'padding': backgroundSettings.padding,
        'scale': backgroundSettings.scale,
      }
    };
    
    await File(configPath).writeAsString(jsonEncode(zoomConfig));
  }

  void _updatePlaybackSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
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
        ? ref.watch(timelineZoomSettingsProvider)[activeZoomLayer.properties['id']] ??
          TimelineZoomSettings(layerId: activeZoomLayer.properties['id'] as String)
        : null;

    // Calculate zoom transform based on settings
    if (zoomSettings != null && activeZoomLayer != null) {
      final layerDuration = activeZoomLayer.endTime - activeZoomLayer.startTime;
      final transitionDuration = (layerDuration * 0.25).clamp(500.0, 1000.0);
      
      // Calculate progress for smooth transitions
      double progress = 1.0;
      if (currentTimeMs - activeZoomLayer.startTime < transitionDuration) {
        // Zoom in
        progress = (currentTimeMs - activeZoomLayer.startTime) / transitionDuration;
        progress = Curves.easeOutCubic.transform(progress);
      } else if (activeZoomLayer.endTime - currentTimeMs < transitionDuration) {
        // Zoom out
        progress = (activeZoomLayer.endTime - currentTimeMs) / transitionDuration;
        progress = Curves.easeInCubic.transform(progress);
      }

      // Apply zoom
      _currentScale = 1.0 + ((zoomSettings.scale - 1.0) * progress);
      
      // Calculate target position
      final targetPosition = zoomSettings.isAutoZoom && _currentCursor != null
          ? _currentOffset
          : zoomSettings.target;
      
      // Calculate translation to center on target
      _currentTranslate = Offset(
        (targetPosition.dx - 0.5) * videoWidth * (_currentScale - 1) / _currentScale,
        (targetPosition.dy - 0.5) * videoHeight * (_currentScale - 1) / _currentScale,
      );
    } else {
      _currentScale = 1.0;
      _currentTranslate = Offset.zero;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Top Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      path.basename(widget.videoPath),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _formatDuration(player.state.duration),
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
                ExportControls(
                  isExporting: _isExporting,
                  playbackSpeed: _playbackSpeed,
                  onExport: _exportVideo,
                  onSpeedChanged: _setPlaybackSpeed,
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // Video Area with zoom
                Expanded(
                  child: Stack(
                    children: [
                      // Background for letterboxing/pillarboxing
                      Container(
                        color: Colors.grey[900],
                      ),
                      Center(
                        child: SizedBox(
                          width: videoWidth,
                          height: videoHeight,
                          child: ClipRect(
                            child: Transform(
                              transform: Matrix4.identity()
                                ..translate(-_currentTranslate.dx, -_currentTranslate.dy)
                                ..scale(_currentScale),
                              alignment: Alignment.center,
                              filterQuality: FilterQuality.high,
                              child: Container(
                                width: videoWidth,
                                height: videoHeight,
                                color: ref.watch(backgroundSettingsProvider).color ?? Colors.black,
                                child: Stack(
                                  children: [
                                    Center(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          ref.watch(backgroundSettingsProvider).cornerRadius,
                                        ),
                                        child: SizedBox(
                                          width: videoWidth * ref.watch(backgroundSettingsProvider).scale,
                                          height: videoHeight * ref.watch(backgroundSettingsProvider).scale,
                                          child: Stack(
                                            children: [
                                              Video(
                                                controller: controller,
                                                filterQuality: FilterQuality.high,
                                                fit: BoxFit.cover,
                                              ),
                                              // Cursor overlay inside video bounds
                                              if (_currentCursor != null && 
                                                  cursorSettings.isVisible && 
                                                  _currentOffset.dx >= 0 && 
                                                  _currentOffset.dy >= 0)
                                                Positioned(
                                                  left: _currentOffset.dx * (videoWidth * ref.watch(backgroundSettingsProvider).scale),
                                                  top: _currentOffset.dy * (videoHeight * ref.watch(backgroundSettingsProvider).scale),
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
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Playback controls without zoom transform
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
                                          if (player.state.playing) {
                                            player.pause();
                                          } else {
                                            player.play();
                                          }
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
                if (_showEditor)
                  Container(
                    width: 300,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      border: Border(
                        left: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Cursor Settings Panel
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF252525),
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.mouse, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text(
                                      'Cursor Settings',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Consumer(
                                  builder: (context, ref, _) {
                                    final settings = ref.watch(cursorSettingsProvider);
                                    final notifier = ref.read(cursorSettingsProvider.notifier);
                                    
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Size: ${(settings.size * 100).toStringAsFixed(0)}%',
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                        SliderTheme(
                                          data: SliderThemeData(
                                            activeTrackColor: Colors.blue,
                                            thumbColor: Colors.blue,
                                            overlayColor: Colors.blue.withOpacity(0.2),
                                            inactiveTrackColor: Colors.grey[800],
                                          ),
                                          child: Slider(
                                            value: settings.size,
                                            min: 0.5,
                                            max: 2.0,
                                            onChanged: (value) => notifier.updateSize(value),
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 16),
                                        
                                        Text(
                                          'Opacity: ${(settings.opacity * 100).toStringAsFixed(0)}%',
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                        SliderTheme(
                                          data: SliderThemeData(
                                            activeTrackColor: Colors.blue,
                                            thumbColor: Colors.blue,
                                            overlayColor: Colors.blue.withOpacity(0.2),
                                            inactiveTrackColor: Colors.grey[800],
                                          ),
                                          child: Slider(
                                            value: settings.opacity,
                                            min: 0.1,
                                            max: 1.0,
                                            onChanged: (value) => notifier.updateOpacity(value),
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 16),
                                        
                                        Row(
                                          children: [
                                            const Text(
                                              'Cursor Color',
                                              style: TextStyle(color: Colors.white70),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => Theme(
                                                    data: ThemeData.dark(),
                                                    child: AlertDialog(
                                                      backgroundColor: const Color(0xFF2A2A2A),
                                                      title: const Text('Select Cursor Color'),
                                                      content: SingleChildScrollView(
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            _ColorButton(
                                                              color: null,
                                                              name: 'Default',
                                                              onSelect: () {
                                                                notifier.updateTintColor(null);
                                                                Navigator.pop(context);
                                                              },
                                                            ),
                                                            _ColorButton(
                                                              color: Colors.white,
                                                              name: 'White',
                                                              onSelect: () {
                                                                notifier.updateTintColor(Colors.white);
                                                                Navigator.pop(context);
                                                              },
                                                            ),
                                                            _ColorButton(
                                                              color: Colors.black,
                                                              name: 'Black',
                                                              onSelect: () {
                                                                notifier.updateTintColor(Colors.black);
                                                                Navigator.pop(context);
                                                              },
                                                            ),
                                                            _ColorButton(
                                                              color: Colors.blue,
                                                              name: 'Blue',
                                                              onSelect: () {
                                                                notifier.updateTintColor(Colors.blue);
                                                                Navigator.pop(context);
                                                              },
                                                            ),
                                                            _ColorButton(
                                                              color: Colors.red,
                                                              name: 'Red',
                                                              onSelect: () {
                                                                notifier.updateTintColor(Colors.red);
                                                                Navigator.pop(context);
                                                              },
                                                            ),
                                                            _ColorButton(
                                                              color: Colors.green,
                                                              name: 'Green',
                                                              onSelect: () {
                                                                notifier.updateTintColor(Colors.green);
                                                                Navigator.pop(context);
                                                              },
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: settings.tintColor ?? Colors.transparent,
                                                  border: Border.all(
                                                    color: Colors.white.withOpacity(0.3),
                                                  ),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: settings.tintColor == null
                                                    ? const Icon(Icons.block, size: 16, color: Colors.white54)
                                                    : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Background Settings Panel
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF151515),
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withOpacity(0.05),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.palette, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text(
                                      'Background Settings',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                BackgroundSettingsPanel(),
                              ],
                            ),
                          ),

                          // Zoom Settings Panel (Only shown when zoom layer is selected)
                          if (timeline.selectedSegments.isNotEmpty &&
                              timeline.segments
                                  .where((s) => timeline.selectedSegments.contains(s.properties['id']))
                                  .any((s) => s.layerType == LayerType.zoom))
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF151515),
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.white.withOpacity(0.05),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.zoom_in, color: Colors.orange),
                                      SizedBox(width: 8),
                                      Text(
                                        'Zoom Layer Settings',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Consumer(
                                    builder: (context, ref, child) {
                                      final selectedLayer = timeline.segments
                                          .firstWhere((s) => 
                                            timeline.selectedSegments.contains(s.properties['id']) &&
                                            s.layerType == LayerType.zoom);
                                      final layerId = selectedLayer.properties['id'] as String;
                                      final zoomSettings = ref.watch(timelineZoomSettingsProvider)[layerId] ??
                                          TimelineZoomSettings(layerId: layerId);
                                      final notifier = ref.read(timelineZoomSettingsProvider.notifier);

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SwitchListTile(
                                            title: const Text(
                                              'Auto Zoom',
                                              style: TextStyle(color: Colors.white70),
                                            ),
                                            subtitle: const Text(
                                              'Follow cursor automatically',
                                              style: TextStyle(color: Colors.white54, fontSize: 12),
                                            ),
                                            value: zoomSettings.isAutoZoom,
                                            activeColor: Colors.orange,
                                            onChanged: (value) => notifier.updateSettings(
                                              layerId,
                                              isAutoZoom: value,
                                            ),
                                          ),
                                          
                                          const SizedBox(height: 16),
                                          
                                          if (!zoomSettings.isAutoZoom) ...[
                                            const Text(
                                              'Target Position',
                                              style: TextStyle(color: Colors.white70),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'X: ${zoomSettings.target.dx.toStringAsFixed(2)}',
                                                        style: const TextStyle(color: Colors.white54),
                                                      ),
                                                      SliderTheme(
                                                        data: SliderThemeData(
                                                          activeTrackColor: Colors.orange,
                                                          thumbColor: Colors.orange,
                                                          overlayColor: Colors.orange.withOpacity(0.2),
                                                          inactiveTrackColor: Colors.grey[800],
                                                        ),
                                                        child: Slider(
                                                          value: zoomSettings.target.dx,
                                                          min: 0,
                                                          max: 1,
                                                          onChanged: (value) => notifier.updateSettings(
                                                            layerId,
                                                            target: Offset(value, zoomSettings.target.dy),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Y: ${zoomSettings.target.dy.toStringAsFixed(2)}',
                                                        style: const TextStyle(color: Colors.white54),
                                                      ),
                                                      SliderTheme(
                                                        data: SliderThemeData(
                                                          activeTrackColor: Colors.orange,
                                                          thumbColor: Colors.orange,
                                                          overlayColor: Colors.orange.withOpacity(0.2),
                                                          inactiveTrackColor: Colors.grey[800],
                                                        ),
                                                        child: Slider(
                                                          value: zoomSettings.target.dy,
                                                          min: 0,
                                                          max: 1,
                                                          onChanged: (value) => notifier.updateSettings(
                                                            layerId,
                                                            target: Offset(zoomSettings.target.dx, value),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          
                                          const SizedBox(height: 16),
                                          
                                          Text(
                                            'Scale: ${(zoomSettings.scale * 100).toStringAsFixed(0)}%',
                                            style: const TextStyle(color: Colors.white70),
                                          ),
                                          SliderTheme(
                                            data: SliderThemeData(
                                              activeTrackColor: Colors.orange,
                                              thumbColor: Colors.orange,
                                              overlayColor: Colors.orange.withOpacity(0.2),
                                              inactiveTrackColor: Colors.grey[800],
                                            ),
                                            child: Slider(
                                              value: zoomSettings.scale,
                                              min: 1.0,
                                              max: 5.0,
                                              onChanged: (value) => notifier.updateSettings(
                                                layerId,
                                                scale: value,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Timeline
          if (!_isFullScreen)
            SizedBox(
              height: timelineHeight,
              child: TimelineEditor(
                videoDuration: player.state.duration,
                currentPosition: player.state.position,
                onSeek: (position) {
                  player.seek(position);
                  _updateCursorPosition(position.inMilliseconds);
                },
                videoPath: widget.videoPath,
              ),
            ),
        ],
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final Color? color;
  final String name;
  final VoidCallback onSelect;

  const _ColorButton({
    required this.color,
    required this.name,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color ?? Colors.transparent,
          border: Border.all(
            color: Colors.black.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: color == null
            ? const Icon(Icons.block, size: 16)
            : null,
      ),
      title: Text(name),
      onTap: onSelect,
    );
  } 
}