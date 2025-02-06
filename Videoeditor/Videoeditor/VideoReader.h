#pragma once
#include <opencv2/opencv.hpp>
#include <string>
#include <windows.h>

class VideoReader {
private:
    cv::VideoCapture cap;
    bool isOpen;
    std::string lastError;

public:
    VideoReader();
    bool open(const std::string& filename);
    bool readFrame(cv::Mat& frame);
    const std::string& getLastError() const;
    void release();
    bool isOpened() const;
}; 