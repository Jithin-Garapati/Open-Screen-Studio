#pragma once
#include <opencv2/opencv.hpp>
#include <string>

class DisplayManager {
private:
    std::string windowName;
    bool isInitialized;
    struct {
        int width;
        int height;
    } windowSize;

public:
    DisplayManager(const std::string& name = "Video Editor");
    void initialize();
    void showFrame(const cv::Mat& frame);
    void cleanup();
    bool isOpen() const;
}; 