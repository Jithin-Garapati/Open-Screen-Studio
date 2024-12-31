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
import '../widgets/video_editor_panel.dart';
import '../providers/cursor_settings_provider.dart';
import '../providers/auto_zoom_provider.dart';
import '../widgets/timeline_editor.dart';
import '../services/ffmpeg_service.dart';
import 'dart:async';

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
  late final AnimationController _animationController;
  Offset _currentOffset = Offset.zero;
  bool _isFullScreen = false;
  double _playbackSpeed = 1.0;
  VideoExportFormat _selectedFormat = VideoExportFormat.mp4_169;
  bool _showEditor = true;
  
  // Add transform values for zoom
  double _currentScale = 1.0;
  Offset _currentTranslate = Offset.zero;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _translateAnimation;

  @override
  void initState() {
    super.initState();
    setWindowForPreview();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Initialize animations with default values
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _translateAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    player.open(Media(widget.videoPath));
    
    // More frequent position updates
    player.stream.position.listen((_) {
      if (!mounted) return;
      WidgetsBinding.instance.scheduleFrameCallback((_) {
        _updateCursorPosition();
      });
    }, cancelOnError: false);
  }

  void _updateCursorPosition() {
    final cursorState = ref.read(cursorTrackingProvider);
    final autoZoom = ref.read(autoZoomProvider);
    
    if (cursorState.positions.isEmpty) return;

    final currentTime = player.state.position.inMilliseconds;
    
    // Find the closest cursor position
    int index = 0;
    int minDiff = (cursorState.positions[0].timestamp - currentTime).abs();
    
    for (int i = 1; i < cursorState.positions.length; i++) {
      final diff = (cursorState.positions[i].timestamp - currentTime).abs();
      if (diff < minDiff) {
        minDiff = diff;
        index = i;
      }
    }
    
    _currentCursor = cursorState.positions[index];

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

      if (autoZoom.enabled && isInBounds) {
        _updateZoom();
      }
    }
  }

  void _updateZoom() {
    if (_currentCursor == null) return;
    final autoZoom = ref.read(autoZoomProvider);
    
    // Calculate target scale and translation
    final targetScale = autoZoom.enabled ? autoZoom.zoomLevel : 1.0;
    
    // Calculate target translation to center the cursor
    final targetTranslate = autoZoom.enabled
        ? Offset(
            0.5 - _currentCursor!.x,
            0.5 - _currentCursor!.y,
          ) * targetScale
        : Offset.zero;

    // Create animations
    _scaleAnimation = Tween<double>(
      begin: _currentScale,
      end: targetScale,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _translateAnimation = Tween<Offset>(
      begin: _currentTranslate,
      end: targetTranslate,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Reset and start animation
    _animationController.duration = Duration(
      milliseconds: autoZoom.transitionDuration.toInt(),
    );
    _animationController
      ..reset()
      ..forward();

    // Update current values
    _currentScale = targetScale;
    _currentTranslate = targetTranslate;
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

  @override
  void dispose() {
    _animationController.dispose();
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
    
    const videoAspectRatio = 16 / 9;
    final videoHeight = availableHeight;
    final videoWidth = videoHeight * videoAspectRatio;
    final videoX = (size.width - (_showEditor ? 300 : 0) - videoWidth) / 2;
    final videoY = appBarHeight;

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
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) => Positioned(
                          left: videoX,
                          top: videoY,
                          width: videoWidth,
                          height: videoHeight,
                          child: Transform(
                            transform: Matrix4.identity()
                              ..translate(
                                _translateAnimation.value.dx * videoWidth,
                                _translateAnimation.value.dy * videoHeight,
                              )
                              ..scale(_scaleAnimation.value),
                            alignment: Alignment.center,
                            child: Video(controller: controller),
                          ),
                        ),
                      ),
                      
                      // Cursor Overlay - only show if cursor is in bounds
                      if (_currentCursor != null && 
                          cursorSettings.isVisible && 
                          _currentOffset.dx >= 0 && 
                          _currentOffset.dy >= 0)
                        TweenAnimationBuilder<Offset>(
                          tween: Tween(begin: _currentOffset, end: _currentOffset),
                          duration: const Duration(milliseconds: 4),
                          curve: Curves.linear,
                          builder: (context, offset, child) => Positioned(
                            left: videoX + (offset.dx * videoWidth),
                            top: videoY + (offset.dy * videoHeight),
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
                                    filterQuality: FilterQuality.none,
                                  ),
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
                                        onPressed: () => player.playOrPause(),
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
                                          _updateZoom();
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
                  const VideoEditorPanel(),
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