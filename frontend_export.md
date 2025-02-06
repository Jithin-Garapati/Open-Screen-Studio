# Frontend Export Functionality

## Overview
The frontend needs to generate and manage three essential files for the C++ backend:
1. Video file (recorded or imported)
2. Cursor data (JSON)
3. Zoom configuration (JSON)

## Current Implementation

### Video File
- Generated during screen recording via `RecordingController`
- Path is stored and passed to the video editor screen
- Accessible via `widget.videoPath` in `VideoEditorScreen`

### Cursor Data
Currently generated automatically during recording:
```dart
// In RecordingController.stopRecording():
if (cursorState.positions.isNotEmpty) {
  final cursorDataPath = path.join(
    path.dirname(outputPath),
    '${originalFileName}_cursor_data.json'
  );
  
  final cursorData = {
    'positions': cursorState.positions.map((pos) => {
      'x': pos.x,
      'y': pos.y,
      'timestamp': pos.timestamp,
      'cursorType': pos.cursorType,
    }).toList(),
  };
  
  await File(cursorDataPath).writeAsString(jsonEncode(cursorData));
}
```

### Zoom Configuration
Currently managed through various providers:
- `timelineZoomSettingsProvider`
- `zoomSettingsProvider`
- `backgroundSettingsProvider`
- `cursorSettingsProvider`

## Required Changes for Export

### 1. Video Export Service
Need to enhance `VideoExportService` to:
```dart
class VideoExportService {
  static Future<String> exportVideo({
    required String inputPath,
    required String outputPath,
    required String cursorDataPath,
    required String zoomConfigPath,
    required double playbackSpeed,
    required VideoExportFormat format,
  }) async {
    // Implementation needed
  }
}
```

### 2. Zoom Configuration Export
Need to implement a function to collect and export zoom settings that exactly matches the C++ backend requirements:
```dart
Future<String> exportZoomConfig(String basePath) async {
  // Get settings from providers
  final timelineZoomSettings = ref.read(timelineZoomSettingsProvider);
  final cursorSettings = ref.read(cursorSettingsProvider);
  final backgroundSettings = ref.read(backgroundSettingsProvider);
  final timeline = ref.read(timelineProvider);

  // Prepare zoom configuration matching C++ backend format
  final zoomConfig = {
    'zoom': {
      'type': 'Auto',  // or 'Manual' based on settings
      'autoLayers': timeline.segments
          .where((segment) => segment.isLayer && segment.layerType == LayerType.zoom)
          .map((layer) {
        final settings = timelineZoomSettings[layer.properties['id']];
        return {
          'startFrame': layer.startTime ~/ (1000 / fps),  // Convert ms to frame number
          'endFrame': layer.endTime ~/ (1000 / fps),
          'minScale': 1.0,
          'maxScale': settings?.scale ?? 2.0,
          'followSpeed': 0.3,  // Default from C++ backend
          'smoothing': 0.7,    // Default from C++ backend
        };
      }).toList(),
      'manualLayers': timeline.segments
          .where((segment) => segment.isLayer && segment.layerType == LayerType.zoom && !settings.isAutoZoom)
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

  final configPath = path.join(
    path.dirname(basePath),
    '${path.basenameWithoutExtension(basePath)}_zoom_config.json'
  );
  
  await File(configPath).writeAsString(jsonEncode(zoomConfig));
  return configPath;
}
```

### 3. Export Button Handler
Need to modify the `_exportVideo` function in `VideoEditorScreen`:
```dart
Future<void> _exportVideo() async {
  if (_isExporting) return;
  setState(() => _isExporting = true);

  try {
    final basePath = widget.videoPath;
    final outputPath = path.join(
      path.dirname(basePath),
      'exported_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    // Get or generate cursor data path
    final cursorDataPath = path.join(
      path.dirname(basePath),
      '${path.basenameWithoutExtension(basePath)}_cursor_data.json'
    );

    // Export zoom configuration
    final zoomConfigPath = await exportZoomConfig(basePath);

    // Export video with all configurations
    await VideoExportService.exportVideo(
      inputPath: basePath,
      outputPath: outputPath,
      cursorDataPath: cursorDataPath,
      zoomConfigPath: zoomConfigPath,
      playbackSpeed: _playbackSpeed,
      format: _selectedFormat,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video exported successfully to: $outputPath')),
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
```

## Next Steps

1. **Implementation Priority**:
   - Implement zoom configuration export exactly as specified
   - Enhance VideoExportService to handle all files
   - Add error handling for missing files
   - Add progress feedback during export

2. **Data Validation**:
   - Validate cursor data format
   - Validate zoom configuration against C++ requirements
   - Ensure all required fields are present
   - Add type checking for all numeric values

3. **User Interface**:
   - Add export format selection
   - Add export progress indicator
   - Add export settings dialog
   - Show preview of export settings 