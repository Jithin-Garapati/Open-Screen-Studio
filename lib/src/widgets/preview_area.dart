import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;
import '../controllers/recording_controller.dart';
import 'cursor_overlay.dart';

class PreviewArea extends ConsumerStatefulWidget {
  const PreviewArea({super.key});

  @override
  ConsumerState<PreviewArea> createState() => _PreviewAreaState();
}

class _PreviewAreaState extends ConsumerState<PreviewArea> {
  ui.Image? _previewFrame;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(recordingControllerProvider.notifier);
      controller.addPreviewListener(_updatePreview);
      _startPreview();
    });
  }

  @override
  void didUpdateWidget(PreviewArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    final recordingState = ref.read(recordingControllerProvider);
    if (recordingState.selectedDisplay != null) {
      _startPreview();
    }
  }

  void _startPreview() {
    final controller = ref.read(recordingControllerProvider.notifier);
    final recordingState = ref.read(recordingControllerProvider);
    
    if (recordingState.selectedDisplay != null) {
      controller.removePreviewListener(_updatePreview);
      controller.addPreviewListener(_updatePreview);
      controller.startPreview();
    }
  }

  @override
  void dispose() {
    final controller = ref.read(recordingControllerProvider.notifier);
    
    // Clean up preview frame
    final oldFrame = _previewFrame;
    _previewFrame = null;
    if (oldFrame != null) {
      try {
        oldFrame.dispose();
      } catch (e) {
        print('Error disposing frame: $e');
      }
    }
    
    // Clean up preview
    controller.removePreviewListener(_updatePreview);
    controller.stopPreview();
    
    super.dispose();
  }

  void _updatePreview(ui.Image? frame) {
    if (!mounted) return;
    if (frame == null) return;
    
    try {
      setState(() {
        if (_previewFrame != frame) {
          final oldFrame = _previewFrame;
          _previewFrame = frame;
          if (oldFrame != null && oldFrame != frame) {
            try {
              oldFrame.dispose();
            } catch (e) {
              print('Error disposing frame: $e');
            }
          }
        }
      });
    } catch (e) {
      print('Error updating preview: $e');
      frame.dispose();
    }
  }

  Widget _buildStatusBadge(RecordingState state) {
    Color color;
    IconData icon;
    String text;
    bool showDot = false;

    switch (state.status) {
      case RecordingStatus.recording:
        color = const Color(0xFFFF3333);
        icon = Icons.fiber_manual_record;
        text = 'RECORDING';
        showDot = true;
        break;
      case RecordingStatus.paused:
        color = Colors.orange;
        icon = Icons.pause;
        text = 'PAUSED';
        break;
      case RecordingStatus.saving:
        color = Colors.blue;
        icon = Icons.save;
        text = 'SAVING...';
        showDot = true;
        break;
      case RecordingStatus.saved:
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'SAVED';
        break;
      case RecordingStatus.error:
        color = Colors.red;
        icon = Icons.error;
        text = 'ERROR';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            )
          else
            Icon(
              icon,
              size: 12,
              color: color,
            ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(recordingControllerProvider);
    final selectedDisplay = recordingState.selectedDisplay;
    final screensAsync = ref.watch(availableScreensProvider);
    final cursorPosition = ref.watch(cursorPositionProvider);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate preview dimensions
          final previewWidth = constraints.maxWidth * 0.8;
          final previewHeight = constraints.maxHeight * 0.8;
          final displayAspectRatio = selectedDisplay != null
              ? selectedDisplay.width / selectedDisplay.height
              : 16 / 9;
          
          // Calculate actual preview dimensions maintaining aspect ratio
          late final double actualWidth;
          late final double actualHeight;
          if (previewWidth / previewHeight > displayAspectRatio) {
            actualHeight = previewHeight;
            actualWidth = previewHeight * displayAspectRatio;
          } else {
            actualWidth = previewWidth;
            actualHeight = previewWidth / displayAspectRatio;
          }

          // Calculate scale factors for cursor position
          final scaleX = selectedDisplay != null ? actualWidth / selectedDisplay.width : 1.0;
          final scaleY = selectedDisplay != null ? actualHeight / selectedDisplay.height : 1.0;

          return Stack(
            children: [
              Center(
                child: SizedBox(
                  width: previewWidth,
                  height: previewHeight,
                  child: Center(
                    child: Container(
                      width: actualWidth,
                      height: actualHeight,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _previewFrame != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  RepaintBoundary(
                                    child: RawImage(
                                      image: _previewFrame,
                                      fit: BoxFit.fill,
                                      width: actualWidth,
                                      height: actualHeight,
                                      scale: 1.0,
                                      filterQuality: FilterQuality.low,
                                    ),
                                  ),
                                  if (cursorPosition != null && selectedDisplay != null)
                                    Positioned(
                                      left: (cursorPosition.dx - selectedDisplay.x) * scaleX,
                                      top: (cursorPosition.dy - selectedDisplay.y) * scaleY,
                                      child: const CursorOverlay(),
                                    ),
                                  if (recordingState.status != RecordingStatus.idle)
                                    Positioned(
                                      top: 16,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: _buildStatusBadge(recordingState),
                                      ),
                                    ),
                                ],
                              )
                            : Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.desktop_windows_outlined,
                                        size: 48,
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ShaderMask(
                                      shaderCallback: (bounds) => LinearGradient(
                                        colors: [
                                          Theme.of(context).colorScheme.primary,
                                          Theme.of(context).colorScheme.secondary,
                                        ],
                                      ).createShader(bounds),
                                      child: const Text(
                                        'PREVIEW AREA',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    screensAsync.when(
                                      data: (screens) => Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Select a screen to record:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.white.withOpacity(0.7),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ...screens.map((screen) {
                                            final isSelected = selectedDisplay?.id == screen.id;
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () {
                                                    ref.read(recordingControllerProvider.notifier).selectDisplay(screen);
                                                  },
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                                                          : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: isSelected
                                                            ? Theme.of(context).colorScheme.primary
                                                            : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.desktop_windows_outlined,
                                                          size: 20,
                                                          color: isSelected
                                                              ? Theme.of(context).colorScheme.primary
                                                              : Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          '${screen.name} (${screen.width}x${screen.height})',
                                                          style: TextStyle(
                                                            color: isSelected
                                                                ? Theme.of(context).colorScheme.primary
                                                                : Colors.white.withOpacity(0.7),
                                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                      loading: () => const CircularProgressIndicator(),
                                      error: (error, stack) => Text(
                                        'Error loading screens',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.error,
                                        ),
                                      ),
                                    ),
                                    if (selectedDisplay != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Display: ${selectedDisplay.width}x${selectedDisplay.height}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.3),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              // Corner accent
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        width: 2,
                      ),
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              // Corner accent
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        width: 2,
                      ),
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
} 