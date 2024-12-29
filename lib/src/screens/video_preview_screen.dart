import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import '../config/window_config.dart';
import '../controllers/cursor_tracking_controller.dart';
import '../models/cursor_position.dart';
import '../services/cursor_tracker.dart';
import '../widgets/video_editor_panel.dart';
import '../providers/cursor_settings_provider.dart';
import '../providers/auto_zoom_provider.dart';
import '../widgets/timeline_editor.dart';

enum VideoExportFormat {
  mp4_169, // 16:9
  mp4_916, // 9:16 (vertical)
  mp4_11,  // 1:1 (square)
  gif
}

class VideoPreviewScreen extends ConsumerStatefulWidget {
  final String videoPath;
  const VideoPreviewScreen({super.key, required this.videoPath});

  @override
  ConsumerState<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends ConsumerState<VideoPreviewScreen> with SingleTickerProviderStateMixin {
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
    player.stream.position.listen((_) => _updateCursorPosition());
  }

  void _updateCursorPosition() {
    if (!mounted) return;
    final cursorState = ref.read(cursorTrackingProvider);
    final autoZoom = ref.read(autoZoomProvider);
    
    if (cursorState.positions.isEmpty) return;

    final currentTime = player.state.position.inMilliseconds;
    
    _currentCursor = cursorState.positions.firstWhere(
      (pos) => pos.timestamp >= currentTime,
      orElse: () => cursorState.positions.last,
    );

    if (_currentCursor != null) {
      // Only show cursor if it's within the display bounds (0.0 to 1.0 range)
      final isInBounds = _currentCursor!.x >= 0.0 && 
                        _currentCursor!.x <= 1.0 &&
                        _currentCursor!.y >= 0.0 && 
                        _currentCursor!.y <= 1.0;
                        
      setState(() {
        _currentOffset = isInBounds ? Offset(_currentCursor!.x, _currentCursor!.y) : Offset(-1, -1);
      });

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
        title: const Text('Video Preview'),
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
              // TODO: Implement export with selected format
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
                          duration: Duration(milliseconds: (16 * (1 - cursorSettings.smoothness)).round()),
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