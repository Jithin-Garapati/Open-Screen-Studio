#pragma once
#include <vector>
#include <optional>
#include <cstdint>

// Cursor settings structure
struct CursorSettings {
    double size = 1.0;          // Scale factor (0.5 to 2.0)
    double opacity = 1.0;       // Opacity (0.1 to 1.0)
    uint32_t tintColor = 0;     // Color in ARGB format (0 for default)
    bool hasTint = false;       // Whether tint should be applied
};

// Background settings structure
struct BackgroundSettings {
    uint32_t color = 0xFF000000;  // Color in ARGB format
    double cornerRadius = 12.0;    // Rounded corner radius in pixels
    double padding = 16.0;         // Padding around the video in pixels
    double scale = 1.0;           // Scale factor for the video frame
};

struct ZoomPoint {
    double x;           // Normalized X coordinate (0-1)
    double y;           // Normalized Y coordinate (0-1)
    int64_t timestamp; // Timestamp in milliseconds
};

struct ManualZoomLayer {
    int startFrame;
    int endFrame;
    double startScale;
    double endScale;
    double targetX;     // Fixed target X (0-1)
    double targetY;     // Fixed target Y (0-1)
};

struct AutoZoomLayer {
    int startFrame;
    int endFrame;
    double minScale;    // Minimum zoom scale
    double maxScale;    // Maximum zoom scale
    double followSpeed; // How quickly to follow the cursor (0-1)
    double smoothing;   // Smoothing factor for cursor movement (0-1)
};

struct ZoomConfig {
    enum class Type {
        Manual,
        Auto
    };

    Type type;
    std::vector<ManualZoomLayer> manualLayers;
    std::vector<AutoZoomLayer> autoLayers;
    
    // Default values for auto-zoom
    struct {
        double defaultScale = 1.0;
        double transitionDuration = 0.5;  // seconds
        double minScale = 1.0;
        double maxScale = 2.5;
        double followSpeed = 0.3;
        double smoothing = 0.7;
    } defaults;

    // New settings
    CursorSettings cursor;
    BackgroundSettings background;

    // Helper function to find active layer at a given frame
    std::optional<ManualZoomLayer> getActiveManualLayer(int frameIndex) const {
        for (const auto& layer : manualLayers) {
            if (frameIndex >= layer.startFrame && frameIndex <= layer.endFrame) {
                return layer;
            }
        }
        return std::nullopt;
    }

    std::optional<AutoZoomLayer> getActiveAutoLayer(int frameIndex) const {
        for (const auto& layer : autoLayers) {
            if (frameIndex >= layer.startFrame && frameIndex <= layer.endFrame) {
                return layer;
            }
        }
        return std::nullopt;
    }
}; 