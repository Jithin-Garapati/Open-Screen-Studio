#pragma once
#include <opencv2/opencv.hpp>
#include "ZoomConfig.h"
#include "CursorData.h"

class ZoomProcessor {
private:
    cv::Size originalSize;
    bool firstFrame;
    ZoomConfig config;
    CursorData* cursorData;  // Pointer to cursor data for auto-zoom
    const int TRANSITION_FRAMES = 30;  // Number of frames for transitions

    // Smoothing for auto-zoom
    struct {
        double lastX = 0.5;
        double lastY = 0.5;
        double lastScale = 1.0;
    } smoothedValues;

    // Helper function for smooth interpolation
    double smoothValue(double current, double target, double smoothing) {
        return current + (target - current) * (1.0 - smoothing);
    }

    // Helper function for ease in-out interpolation
    double easeInOutQuad(double t) {
        return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2;
    }

    // Calculate auto-zoom parameters based on cursor position
    void calculateAutoZoom(const AutoZoomLayer& layer, const CursorPosition& cursorPos,
                         double& outScale, double& outTargetX, double& outTargetY,
                         unsigned long frameIndex) {
        // Calculate transition progress for start and end
        double startTransition = static_cast<double>(frameIndex - layer.startFrame) / TRANSITION_FRAMES;
        double endTransition = static_cast<double>(layer.endFrame - frameIndex) / TRANSITION_FRAMES;
        
        startTransition = std::clamp(startTransition, 0.0, 1.0);
        endTransition = std::clamp(endTransition, 0.0, 1.0);

        // Smooth the target position
        smoothedValues.lastX = smoothValue(smoothedValues.lastX, cursorPos.x, layer.smoothing);
        smoothedValues.lastY = smoothValue(smoothedValues.lastY, cursorPos.y, layer.smoothing);

        // Calculate distance from center to determine scale
        double dx = smoothedValues.lastX - 0.5;
        double dy = smoothedValues.lastY - 0.5;
        double distanceFromCenter = std::sqrt(dx * dx + dy * dy);

        // Scale based on distance from center
        double targetScale = layer.minScale + 
            (layer.maxScale - layer.minScale) * (1.0 - distanceFromCenter);
        targetScale = std::clamp(targetScale, layer.minScale, layer.maxScale);

        // Smooth the scale
        smoothedValues.lastScale = smoothValue(smoothedValues.lastScale, targetScale, layer.smoothing);

        // Apply transitions at layer boundaries
        if (frameIndex <= layer.startFrame + TRANSITION_FRAMES) {
            // Ease in from scale 1.0
            double t = easeInOutQuad(startTransition);
            outScale = 1.0 + (smoothedValues.lastScale - 1.0) * t;
            outTargetX = 0.5 + (smoothedValues.lastX - 0.5) * t;
            outTargetY = 0.5 + (smoothedValues.lastY - 0.5) * t;
        }
        else if (frameIndex >= layer.endFrame - TRANSITION_FRAMES) {
            // Ease out to scale 1.0
            double t = easeInOutQuad(endTransition);
            outScale = smoothedValues.lastScale + (1.0 - smoothedValues.lastScale) * (1.0 - t);
            outTargetX = smoothedValues.lastX + (0.5 - smoothedValues.lastX) * (1.0 - t);
            outTargetY = smoothedValues.lastY + (0.5 - smoothedValues.lastY) * (1.0 - t);
        }
        else {
            // Normal auto-zoom behavior
            outScale = smoothedValues.lastScale;
            outTargetX = smoothedValues.lastX;
            outTargetY = smoothedValues.lastY;
        }
    }

public:
    ZoomProcessor() : firstFrame(true), cursorData(nullptr) {}

    void setCursorData(CursorData* data) {
        cursorData = data;
    }

    void setConfig(const ZoomConfig& newConfig) {
        config = newConfig;
        // Reset smoothing values
        smoothedValues = {0.5, 0.5, 1.0};
    }

    void processFrame(const cv::Mat& input, cv::Mat& output, unsigned long frameIndex) {
        if (firstFrame) {
            originalSize = input.size();
            firstFrame = false;
        }

        double scale = 1.0;
        double targetX = 0.5;
        double targetY = 0.5;

        // Handle manual zoom layers
        if (auto manualLayer = config.getActiveManualLayer(frameIndex)) {
            // Calculate base progress through the layer
            double progress = static_cast<double>(frameIndex - manualLayer->startFrame) /
                            (manualLayer->endFrame - manualLayer->startFrame);
            progress = std::clamp(progress, 0.0, 1.0);

            // Calculate transition progress for start and end
            double startTransition = static_cast<double>(frameIndex - manualLayer->startFrame) / TRANSITION_FRAMES;
            double endTransition = static_cast<double>(manualLayer->endFrame - frameIndex) / TRANSITION_FRAMES;
            
            startTransition = std::clamp(startTransition, 0.0, 1.0);
            endTransition = std::clamp(endTransition, 0.0, 1.0);

            // Apply ease-in at start and ease-out at end
            if (frameIndex <= manualLayer->startFrame + TRANSITION_FRAMES) {
                // Ease in
                scale = 1.0 + (manualLayer->startScale - 1.0) * easeInOutQuad(startTransition);
            }
            else if (frameIndex >= manualLayer->endFrame - TRANSITION_FRAMES) {
                // Ease out
                scale = manualLayer->endScale + (1.0 - manualLayer->endScale) * (1.0 - easeInOutQuad(endTransition));
            }
            else {
                // Full zoom during middle of layer
                scale = manualLayer->startScale;
            }

            targetX = manualLayer->targetX;
            targetY = manualLayer->targetY;
        }
        // Handle auto zoom layers
        else if (auto autoLayer = config.getActiveAutoLayer(frameIndex)) {
            if (cursorData) {
                CursorPosition cursorPos = cursorData->getPositionAtFrame(frameIndex);
                calculateAutoZoom(*autoLayer, cursorPos, scale, targetX, targetY, frameIndex);
            }
        }

        // Apply zoom effect
        int newWidth = static_cast<int>(originalSize.width * scale);
        int newHeight = static_cast<int>(originalSize.height * scale);

        // Create zoomed version of the frame
        cv::Mat zoomed;
        cv::resize(input, zoomed, cv::Size(newWidth, newHeight), 0, 0, cv::INTER_LINEAR);

        // Calculate crop region
        int x = static_cast<int>((newWidth - originalSize.width) * targetX);
        int y = static_cast<int>((newHeight - originalSize.height) * targetY);

        // Ensure we don't go out of bounds
        x = std::clamp(x, 0, newWidth - originalSize.width);
        y = std::clamp(y, 0, newHeight - originalSize.height);

        // Crop the region
        cv::Rect roi(x, y, originalSize.width, originalSize.height);
        output = zoomed(roi).clone();
    }
}; 