import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../providers/cursor_settings_provider.dart';
import '../features/timeline/providers/timeline_provider.dart';
import '../features/timeline/presentation/widgets/zoom_settings_panel.dart';
import '../features/timeline/providers/zoom_settings_provider.dart';
import '../features/timeline/models/timeline_segment.dart';
import 'dart:developer' as developer;

class VideoEditorPanel extends ConsumerWidget {
  final VideoController videoController;
  final Duration currentPosition;
  final Size videoSize;

  const VideoEditorPanel({
    super.key,
    required this.videoController,
    required this.currentPosition,
    required this.videoSize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cursorSettings = ref.watch(cursorSettingsProvider);
    final cursorSettingsNotifier = ref.read(cursorSettingsProvider.notifier);
    final timeline = ref.watch(timelineProvider);
    final selectedSegments = timeline.selectedSegments;
    
    developer.log('Selected segments: $selectedSegments');
    
    // Get the first selected segment
    final selectedLayer = selectedSegments.isNotEmpty 
        ? timeline.segments.firstWhere(
            (s) {
              developer.log('Checking segment: ${s.properties}');
              return selectedSegments.contains(s.properties['id']);
            },
            orElse: () => TimelineSegment(
              startTime: 0,
              endTime: 0,
              type: SegmentType.layer,
              color: Colors.transparent,
              properties: const {},
            ),
          )
        : null;

    developer.log('Selected layer: ${selectedLayer?.properties}');
    developer.log('Layer type: ${selectedLayer?.layerType}');

    // Check if it's a zoom layer
    final isZoomLayer = selectedLayer?.layerType == LayerType.zoom;
    developer.log('Is zoom layer: $isZoomLayer');
    
    // Get zoom settings for the selected layer
    final zoomSettings = isZoomLayer && selectedLayer != null
        ? ref.watch(zoomSettingsProvider)[selectedLayer.properties['id']] 
        : null;
    developer.log('Zoom settings: $zoomSettings');

    final zoomSettingsNotifier = ref.read(zoomSettingsProvider.notifier);

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: Border(
          left: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.edit, color: Colors.white70, size: 20),
                SizedBox(width: 8),
                Text(
                  'Editor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (isZoomLayer && zoomSettings != null) ...[
                  // Show zoom settings when a zoom layer is selected
                  ZoomSettingsPanel(
                    settings: zoomSettings,
                    onSettingsChanged: (settings) {
                      if (selectedLayer != null) {
                        zoomSettingsNotifier.updateSettings(
                          selectedLayer.properties['id'],
                          settings,
                        );
                      }
                    },
                    onTargetModeToggle: () {
                      // Toggle target mode
                      final currentId = ref.read(activeZoomLayerProvider);
                      ref.read(activeZoomLayerProvider.notifier).state = 
                          currentId == selectedLayer?.properties['id'] ? null : selectedLayer?.properties['id'];
                    },
                    isTargetMode: ref.watch(activeZoomLayerProvider) == selectedLayer?.properties['id'],
                    videoController: videoController,
                    currentPosition: currentPosition,
                    videoSize: videoSize,
                  ),
                ] else ...[
                  // Show cursor settings when no zoom layer is selected
                  _buildSectionHeader('Cursor Settings'),
                  const SizedBox(height: 16),

                  // Cursor Size
                  _buildLabel('Size'),
                  Slider(
                    value: cursorSettings.size,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    label: cursorSettings.size.toStringAsFixed(2),
                    onChanged: cursorSettingsNotifier.updateSize,
                  ),
                  const SizedBox(height: 24),

                  // Cursor Smoothness
                  _buildLabel('Smoothness'),
                  Slider(
                    value: cursorSettings.smoothness,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    label: cursorSettings.smoothness.toStringAsFixed(2),
                    onChanged: cursorSettingsNotifier.updateSmoothness,
                  ),
                  const SizedBox(height: 24),

                  // Cursor Opacity
                  _buildLabel('Opacity'),
                  Slider(
                    value: cursorSettings.opacity,
                    min: 0.1,
                    max: 1.0,
                    divisions: 18,
                    label: '${(cursorSettings.opacity * 100).toStringAsFixed(0)}%',
                    onChanged: cursorSettingsNotifier.updateOpacity,
                  ),
                  const SizedBox(height: 24),

                  // Cursor Visibility
                  _buildSwitchRow(
                    'Show Cursor',
                    cursorSettings.isVisible,
                    (value) => cursorSettingsNotifier.toggleVisibility(),
                  ),
                  const SizedBox(height: 16),

                  // Cursor Color
                  _buildLabel('Cursor Color'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildColorOption(null, cursorSettings.tintColor, cursorSettingsNotifier),
                      _buildColorOption(Colors.white, cursorSettings.tintColor, cursorSettingsNotifier),
                      _buildColorOption(Colors.black, cursorSettings.tintColor, cursorSettingsNotifier),
                      _buildColorOption(Colors.blue, cursorSettings.tintColor, cursorSettingsNotifier),
                      _buildColorOption(Colors.red, cursorSettings.tintColor, cursorSettingsNotifier),
                      _buildColorOption(Colors.green, cursorSettings.tintColor, cursorSettingsNotifier),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Reset Button
                  Center(
                    child: TextButton.icon(
                      onPressed: cursorSettingsNotifier.reset,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reset to Default'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
      ),
    );
  }

  Widget _buildSwitchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildColorOption(Color? color, Color? selectedColor, CursorSettingsNotifier notifier) {
    final isSelected = color == selectedColor;
    final isDefault = color == null && selectedColor == null;

    return GestureDetector(
      onTap: () => notifier.updateTintColor(color),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color ?? Colors.transparent,
          border: Border.all(
            color: isSelected || isDefault
                ? Colors.blue
                : Colors.white.withOpacity(0.1),
            width: isSelected || isDefault ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: isDefault
            ? const Icon(Icons.block, color: Colors.white70, size: 20)
            : null,
      ),
    );
  }
} 