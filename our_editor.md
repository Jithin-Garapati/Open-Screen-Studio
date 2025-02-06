# OpenScreen Studio C++ Backend Architecture

## Overview
The C++ backend of OpenScreen Studio is responsible for high-performance video processing, cursor overlay management, and zoom effects. It's built using OpenCV for video manipulation and custom implementations for cursor and zoom handling.

## Core Components

### 1. Video Editor (Videoeditor.cpp)
The main component that orchestrates the video processing pipeline:
- Handles video file loading and frame reading using OpenCV
- Manages the processing workflow
- Coordinates between cursor overlay and zoom processing
- Handles file I/O for configuration and cursor data

### 2. Cursor Overlay System (CursorOverlay.h)
Sophisticated cursor management system that:
- Loads and manages different cursor types
- Supports SVG cursor images using nanosvg library
- Handles cursor scaling and tinting
- Provides smooth cursor overlay on video frames
- Maintains cursor alpha channels for proper blending

Key features:
- Dynamic cursor size adjustment
- Cursor tinting and color manipulation
- High-quality SVG rendering
- Multiple cursor type support
- Efficient memory management for cursor images

### 3. Zoom Processor (ZoomProcessor.h)
Advanced zoom effect implementation that provides:
- Automatic zoom based on cursor position
- Smooth transitions between zoom levels
- Configurable zoom parameters
- Frame-by-frame zoom processing

Features:
- Smooth value interpolation
- Ease-in/ease-out transitions
- Distance-based zoom scaling
- Configurable zoom boundaries
- Frame-accurate zoom timing

## Technical Details

### Video Processing
- Uses OpenCV's VideoCapture for frame reading
- Supports various video formats
- Maintains original video properties (FPS, resolution)
- Efficient frame buffer management

### Cursor System
- Base cursor height: 128 pixels
- Supports multiple cursor types via unordered_map
- Separate alpha channel management
- SVG parsing and rasterization
- Dynamic cursor scaling and positioning

### Zoom System
- 30-frame transition windows
- Quadratic easing functions
- Position smoothing
- Scale range: configurable min/max
- Center-based zoom calculations

## Input Requirements

### 1. Video Input File
- Format: Any video format supported by OpenCV (MP4, AVI, MOV, etc.)
- Requirements:
  - Must be a valid video file readable by OpenCV
  - Must have accessible properties (FPS, resolution)
  - Recommended: H.264 codec for optimal compatibility
  - Supports various resolutions and frame rates

### 2. Cursor Data File (JSON)
Required format:
```json
{
  "positions": [
    {
      "x": 0.5,          // Normalized X coordinate (0-1)
      "y": 0.5,          // Normalized Y coordinate (0-1)
      "timestamp": 1000, // Milliseconds since start
      "cursorType": 65539 // Windows cursor type ID
    }
    // ... Additional cursor positions
  ]
}
```

### 3. Zoom Configuration File (JSON)
Required format:
```json
{
  "type": "Auto",  // or "Manual"
  "autoLayers": [
    {
      "startFrame": 0,
      "endFrame": 300,
      "minScale": 1.0,
      "maxScale": 2.5,
      "followSpeed": 0.3,
      "smoothing": 0.7
    }
  ],
  "cursor": {
    "size": 1.0,        // Scale factor (0.5 to 2.0)
    "opacity": 1.0,     // Opacity (0.1 to 1.0)
    "tintColor": 0,     // ARGB format
    "hasTint": false
  },
  "background": {
    "color": 4278190080,  // 0xFF000000 in decimal (ARGB)
    "cornerRadius": 12.0, // Pixels
    "padding": 16.0,     // Pixels
    "scale": 1.0
  }
}
```

Important Notes:
- All coordinates in configuration files are normalized (0-1) for resolution independence
- Files are processed in sequence: video → cursor data → zoom configuration
- JSON files must be valid and complete with all required fields
- Timestamps must be in milliseconds and synchronized with video duration

## Data Flow
1. Video frame capture
2. Zoom processing
   - Auto-zoom calculations
   - Transition handling
   - Frame transformation
3. Cursor overlay
   - Position calculation
   - Scale adjustment
   - Alpha blending
4. Frame output

## Configuration
The system supports JSON-based configuration for:
- Zoom settings
- Cursor properties
- Video export parameters
- Processing parameters

## Performance Considerations
- Efficient memory usage with smart pointers
- Optimized image processing algorithms
- Smooth transition calculations
- Minimal memory allocation during processing
- Efficient cursor caching system 