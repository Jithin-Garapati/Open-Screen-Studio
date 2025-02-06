// Videoeditor.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include <opencv2/opencv.hpp>
#include <iostream>
#include <string>
#include <vector>
#include <chrono>
#include <thread>
#include <filesystem>
#include <iomanip>
#include <windows.h>
#include <shobjidl.h>
#include <fstream>
#include <map>
#include "CursorData.h"
#include "FileSelector.h"
#include "CursorOverlay.h"
#include "ZoomProcessor.h"
#include "ZoomConfig.h"

// Using declarations
using json = nlohmann::json;

// Function to convert wide string to string
std::string wstring_to_string(const std::wstring& wstr) {
    if (wstr.empty()) return "";
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string str(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &str[0], size_needed, NULL, NULL);
    return str;
}

// Structure to hold command-line arguments
struct CommandLineArgs {
    std::string inputPath;
    std::string outputPath;
    std::string cursorDataPath;
    std::string zoomConfigPath;
    double playbackSpeed = 1.0;
    std::string format = "16:9";
    bool showHelp = false;
    bool showVersion = false;
};

// Function to parse command-line arguments
CommandLineArgs parseArgs(int argc, char* argv[]) {
    CommandLineArgs args;
    std::map<std::string, std::string*> argMap = {
        {"--input", &args.inputPath},
        {"--output", &args.outputPath},
        {"--cursor-data", &args.cursorDataPath},
        {"--zoom-config", &args.zoomConfigPath},
        {"--format", &args.format}
    };

    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        
        if (arg == "--help" || arg == "-h") {
            args.showHelp = true;
            return args;
        }
        
        if (arg == "--version" || arg == "-v") {
            args.showVersion = true;
            return args;
        }

        if (arg == "--speed") {
            if (i + 1 < argc) {
                try {
                    args.playbackSpeed = std::stod(argv[++i]);
                } catch (const std::exception&) {
                    throw std::runtime_error("Invalid value for --speed");
                }
            } else {
                throw std::runtime_error("--speed requires a value");
            }
            continue;
        }

        auto it = argMap.find(arg);
        if (it != argMap.end()) {
            if (i + 1 < argc) {
                *it->second = argv[++i];
            } else {
                throw std::runtime_error(arg + " requires a value");
            }
        }
    }

    // Validate required arguments
    if (!args.showHelp && !args.showVersion) {
        if (args.inputPath.empty()) throw std::runtime_error("--input is required");
        if (args.outputPath.empty()) throw std::runtime_error("--output is required");
        if (args.cursorDataPath.empty()) throw std::runtime_error("--cursor-data is required");
        if (args.zoomConfigPath.empty()) throw std::runtime_error("--zoom-config is required");
    }

    return args;
}

// Function to show help message
void showHelp() {
    std::cout << "OpenScreen Studio Video Editor\n\n"
              << "Usage: Videoeditor.exe [options]\n\n"
              << "Options:\n"
              << "  --input <path>         Input video file path\n"
              << "  --output <path>        Output video file path\n"
              << "  --cursor-data <path>   Cursor data JSON file path\n"
              << "  --zoom-config <path>   Zoom configuration JSON file path\n"
              << "  --speed <value>        Playback speed (default: 1.0)\n"
              << "  --format <format>      Output format (16:9, 9:16, 1:1, gif)\n"
              << "  --help, -h             Show this help message\n"
              << "  --version, -v          Show version information\n";
}

// Function to show version information
void showVersion() {
    std::cout << "OpenScreen Studio Video Editor v1.0.0\n";
}

// VideoReader: Handles video file loading and frame reading
class VideoReader {
private:
    cv::VideoCapture cap;
    bool isOpen;
    std::string lastError;

public:
    VideoReader() : isOpen(false) {}

    bool open(const std::string& filename) {
        // Check if file exists using Windows API
        DWORD fileAttributes = GetFileAttributesA(filename.c_str());
        if (fileAttributes == INVALID_FILE_ATTRIBUTES) {
            lastError = "File does not exist: " + filename;
            return false;
        }

        try {
            isOpen = cap.open(filename);
            if (!isOpen) {
                lastError = "Failed to open video capture for: " + filename;
                return false;
            }

            // Get video properties
            double fps = cap.get(cv::CAP_PROP_FPS);
            int width = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_WIDTH));
            int height = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_HEIGHT));
            int totalFrames = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_COUNT));

            std::cout << "Video opened successfully:" << std::endl
                     << "Resolution: " << width << "x" << height << std::endl
                     << "FPS: " << fps << std::endl
                     << "Total Frames: " << totalFrames << std::endl;

            return true;
        }
        catch (const cv::Exception& e) {
            lastError = "OpenCV Exception: " + std::string(e.what());
            return false;
        }
        catch (const std::exception& e) {
            lastError = "Standard Exception: " + std::string(e.what());
            return false;
        }
    }

    bool readFrame(cv::Mat& frame) {
        if (!isOpen) {
            lastError = "Attempting to read from closed video";
            return false;
        }
        try {
            return cap.read(frame);
        }
        catch (const cv::Exception& e) {
            lastError = "Frame reading error: " + std::string(e.what());
            return false;
        }
    }

    const std::string& getLastError() const {
        return lastError;
    }

    void release() {
        if (isOpen) {
            cap.release();
            isOpen = false;
        }
    }

    bool isOpened() const { return isOpen; }

    double getFPS() const {
        return cap.get(cv::CAP_PROP_FPS);
    }

    int getWidth() const {
        return static_cast<int>(cap.get(cv::CAP_PROP_FRAME_WIDTH));
    }

    int getHeight() const {
        return static_cast<int>(cap.get(cv::CAP_PROP_FRAME_HEIGHT));
    }

    int getTotalFrames() const {
        return static_cast<int>(cap.get(cv::CAP_PROP_FRAME_COUNT));
    }
};

int main(int argc, char* argv[])
{
    try {
        // Parse command-line arguments
        CommandLineArgs args = parseArgs(argc, argv);

        // Handle help and version requests
        if (args.showHelp) {
            showHelp();
            return 0;
        }
        if (args.showVersion) {
            showVersion();
            return 0;
        }

        std::string videoPath;
        std::string cursorDataPath;
        std::string zoomConfigPath;
        std::string outputPath;

        if (argc > 1) {
            // Use command-line arguments
            videoPath = args.inputPath;
            cursorDataPath = args.cursorDataPath;
            zoomConfigPath = args.zoomConfigPath;
            outputPath = args.outputPath;
        } else {
            // Fallback to file picker mode for manual testing
            std::cout << "No arguments provided, entering interactive mode...\n\n";
            
            // Select input video file
            std::cout << "Please select the input video file..." << std::endl;
            videoPath = FileSelector::showFileDialog(FileSelector::FileType::Video);
            if (videoPath.empty()) {
                std::cerr << "No video file selected." << std::endl;
                return 1;
            }

            // Select cursor data JSON file
            std::cout << "Please select the cursor data JSON file..." << std::endl;
            cursorDataPath = FileSelector::showFileDialog(FileSelector::FileType::JSON);
            if (cursorDataPath.empty()) {
                std::cerr << "No cursor data file selected." << std::endl;
                return 1;
            }

            // Select zoom configuration JSON file
            std::cout << "Please select the zoom configuration JSON file..." << std::endl;
            zoomConfigPath = FileSelector::showFileDialog(FileSelector::FileType::JSON);
            if (zoomConfigPath.empty()) {
                std::cerr << "No zoom configuration file selected." << std::endl;
                return 1;
            }

            // Select output video file
            std::cout << "Please select the output video file..." << std::endl;
            outputPath = FileSelector::showFileDialog(FileSelector::FileType::Video);
            if (outputPath.empty()) {
                std::cerr << "No output location selected." << std::endl;
                return 1;
            }
        }

        // Create instances of our classes
        VideoReader reader;
        ZoomProcessor processor;
        CursorData cursorData;

        // Open the input video file
        std::cout << "\nOpening video file..." << std::endl;
        if (!reader.open(videoPath)) {
            std::cerr << "Error opening video: " << reader.getLastError() << std::endl;
            return -1;
        }

        // Get video properties
        double fps = reader.getFPS();
        if (fps <= 0) fps = 30.0;  // Fallback to 30fps if unable to get actual FPS

        // Load cursor data
        cursorData.setVideoFPS(fps);
        if (!cursorData.loadFromJson(cursorDataPath)) {
            std::cerr << "Error: Failed to load cursor data from " << cursorDataPath << std::endl;
            return -1;
        }

        // Load zoom configuration
        std::ifstream zoomFile(zoomConfigPath);
        if (!zoomFile.is_open()) {
            std::cerr << "Error: Could not open zoom configuration file" << std::endl;
            return -1;
        }

        json zoomJson;
        ZoomConfig config;
        try {
            zoomFile >> zoomJson;
            
            // Parse cursor settings
            if (zoomJson.contains("cursor")) {
                const auto& cursor = zoomJson["cursor"];
                config.cursor.size = cursor.value("size", 1.0);
                config.cursor.opacity = cursor.value("opacity", 1.0);
                config.cursor.hasTint = cursor.value("hasTint", false);
                if (config.cursor.hasTint) {
                    config.cursor.tintColor = cursor["tintColor"].get<uint32_t>();
                }
            }

            // Parse background settings
            if (zoomJson.contains("background")) {
                const auto& bg = zoomJson["background"];
                config.background.color = bg.value("color", 0xFF000000);
                config.background.cornerRadius = bg.value("cornerRadius", 12.0);
                config.background.padding = bg.value("padding", 16.0);
                config.background.scale = bg.value("scale", 1.0);
            }

            // Parse zoom settings
            if (zoomJson.contains("zoom")) {
                const auto& zoom = zoomJson["zoom"];
                config.type = (zoom.value("type", "Manual") == "Auto") ? ZoomConfig::Type::Auto : ZoomConfig::Type::Manual;
                
                // Load auto layers
                if (zoom.contains("autoLayers")) {
                    for (const auto& layer : zoom["autoLayers"]) {
                        AutoZoomLayer autoLayer;
                        autoLayer.startFrame = layer.value("startFrame", 0);
                        autoLayer.endFrame = layer.value("endFrame", 0);
                        autoLayer.minScale = layer.value("minScale", 1.0);
                        autoLayer.maxScale = layer.value("maxScale", 2.0);
                        autoLayer.followSpeed = layer.value("followSpeed", 0.3);
                        autoLayer.smoothing = layer.value("smoothing", 0.7);
                        config.autoLayers.push_back(autoLayer);
                    }
                }
                
                // Load manual layers
                if (zoom.contains("manualLayers")) {
                    for (const auto& layer : zoom["manualLayers"]) {
                        ManualZoomLayer manualLayer;
                        manualLayer.startFrame = layer.value("startFrame", 0);
                        manualLayer.endFrame = layer.value("endFrame", 0);
                        manualLayer.startScale = layer.value("startScale", 1.0);
                        manualLayer.endScale = layer.value("endScale", 2.0);
                        manualLayer.targetX = layer.value("targetX", 0.5);
                        manualLayer.targetY = layer.value("targetY", 0.5);
                        config.manualLayers.push_back(manualLayer);
                    }
                }
                
                // Load defaults if present
                if (zoom.contains("defaults")) {
                    const auto& defaults = zoom["defaults"];
                    config.defaults.defaultScale = defaults.value("defaultScale", 1.0);
                    config.defaults.transitionDuration = defaults.value("transitionDuration", 0.5);
                    config.defaults.minScale = defaults.value("minScale", 1.0);
                    config.defaults.maxScale = defaults.value("maxScale", 2.5);
                    config.defaults.followSpeed = defaults.value("followSpeed", 0.3);
                    config.defaults.smoothing = defaults.value("smoothing", 0.7);
                }
            }
            
            processor.setConfig(config);
            processor.setCursorData(&cursorData);
        }
        catch (const json::exception& e) {
            std::cerr << "Error parsing zoom configuration: " << e.what() << std::endl;
            return -1;
        }

        // Create output video path
        std::filesystem::path outputVideoPath = outputPath;

        // Get input video properties
        int frameWidth = reader.getWidth();
        int frameHeight = reader.getHeight();
        int totalFrames = reader.getTotalFrames();

        // Create video writer
        cv::VideoWriter writer;
        int fourcc = cv::VideoWriter::fourcc('m', 'p', '4', 'v');  // MP4 codec
        writer.open(outputVideoPath.string(), fourcc, fps, cv::Size(frameWidth, frameHeight), true);

        if (!writer.isOpened()) {
            std::cerr << "Error: Could not create output video file" << std::endl;
            return -1;
        }

        // Initialize cursor overlay with proper path
        CursorOverlay cursor;
        std::string projectPath = std::filesystem::current_path().parent_path().parent_path().string();
        std::string cursorDir = projectPath + "\\Videoeditor\\cursors";
        
        std::cout << "Loading cursors from: " << cursorDir << std::endl;
        if (!cursor.loadCursors(cursorDir)) {
            std::cerr << "Warning: Failed to load cursor images from " << cursorDir << std::endl;
            return -1;
        }

        // Apply cursor settings from zoom config
        cursor.setSettings(config.cursor);

        // Calculate optimal buffer size based on available memory
        const size_t maxBufferMB = 512;  // Maximum 512MB buffer
        const size_t frameSize = frameWidth * frameHeight * 3;  // 3 channels (BGR)
        const size_t maxFramesInBuffer = (maxBufferMB * 1024 * 1024) / frameSize;
        const size_t bufferSize = (std::min)(maxFramesInBuffer, static_cast<size_t>(30));  // Max 30 frames or memory limit

        // Create frame buffers
        std::vector<cv::Mat> frameBuffer;
        std::vector<cv::Mat> processedBuffer;
        frameBuffer.reserve(bufferSize);
        processedBuffer.reserve(bufferSize);

        unsigned long frameIndex = 0;
        cv::Mat frame;
        
        std::cout << "\nProcessing video..." << std::endl;
        std::cout << "Total frames to process: " << totalFrames << std::endl;
        std::cout << "Using buffer size: " << bufferSize << " frames" << std::endl;

        while (true) {
            frameBuffer.clear();
            processedBuffer.clear();

            // Fill buffer with frames
            for (size_t i = 0; i < bufferSize && reader.readFrame(frame); ++i) {
                frameBuffer.push_back(frame.clone());
            }

            if (frameBuffer.empty()) {
                break;  // End of video
            }

            // Process frames in buffer
            for (size_t i = 0; i < frameBuffer.size(); i++) {
                cv::Mat& currentFrame = frameBuffer[i];

                // Create background with specified color
                cv::Mat background(frameHeight, frameWidth, CV_8UC3);
                uint8_t b = config.background.color & 0xFF;
                uint8_t g = (config.background.color >> 8) & 0xFF;
                uint8_t r = (config.background.color >> 16) & 0xFF;
                background.setTo(cv::Scalar(b, g, r));

                // Create a mask for rounded corners
                cv::Mat cornerMask(frameHeight, frameWidth, CV_8UC1, cv::Scalar(0));
                double radius = config.background.cornerRadius;
                
                // Draw rounded rectangle on the mask
                cv::rectangle(cornerMask, 
                    cv::Point(radius, 0), 
                    cv::Point(frameWidth - radius - 1, frameHeight - 1), 
                    cv::Scalar(255), -1);
                cv::rectangle(cornerMask, 
                    cv::Point(0, radius), 
                    cv::Point(frameWidth - 1, frameHeight - radius - 1), 
                    cv::Scalar(255), -1);
                
                // Draw the corner arcs
                cv::ellipse(cornerMask, cv::Point(radius, radius), cv::Size(radius, radius), 
                           180, 0, 90, cv::Scalar(255), -1);
                cv::ellipse(cornerMask, cv::Point(frameWidth - radius - 1, radius), 
                           cv::Size(radius, radius), 270, 0, 90, cv::Scalar(255), -1);
                cv::ellipse(cornerMask, cv::Point(radius, frameHeight - radius - 1), 
                           cv::Size(radius, radius), 90, 0, 90, cv::Scalar(255), -1);
                cv::ellipse(cornerMask, cv::Point(frameWidth - radius - 1, frameHeight - radius - 1), 
                           cv::Size(radius, radius), 0, 0, 90, cv::Scalar(255), -1);

                // Create inverted mask for background
                cv::Mat invertedMask;
                cv::bitwise_not(cornerMask, invertedMask);

                // Apply rounded corners by blending frame with background
                cv::Mat roundedFrame = background.clone();
                currentFrame.copyTo(roundedFrame, cornerMask);

                // Scale down the rounded frame
                cv::Mat scaledFrame;
                double scale = config.background.scale;
                int newWidth = static_cast<int>(frameWidth * scale);
                int newHeight = static_cast<int>(frameHeight * scale);
                cv::resize(roundedFrame, scaledFrame, cv::Size(newWidth, newHeight), 0, 0, cv::INTER_LANCZOS4);

                // Create new background for scaled frame
                cv::Mat finalBackground(frameHeight, frameWidth, CV_8UC3, cv::Scalar(b, g, r));

                // Calculate position to center the scaled frame
                int x = (frameWidth - newWidth) / 2;
                int y = (frameHeight - newHeight) / 2;

                // Create ROI in background for the scaled frame
                cv::Mat roi = finalBackground(cv::Rect(x, y, newWidth, newHeight));
                
                // Copy the scaled frame to the background
                scaledFrame.copyTo(roi);

                // Get cursor position and overlay cursor
                CursorPosition pos = cursorData.getPositionAtFrame(frameIndex + i);
                // Adjust cursor position for scaled frame
                int cursorX = static_cast<int>(pos.x * newWidth) + x;
                int cursorY = static_cast<int>(pos.y * newHeight) + y;
                cursor.overlay(finalBackground, cursorX, cursorY, pos.cursorType);

                // Apply zoom effect
                cv::Mat processedFrame;
                processor.processFrame(finalBackground, processedFrame, frameIndex + i);
                processedBuffer.push_back(processedFrame);
            }

            // Write processed frames
            for (const auto& processedFrame : processedBuffer) {
                writer.write(processedFrame);
            }

            frameIndex += frameBuffer.size();

            // Show progress
            float progress = (frameIndex * 100.0f) / totalFrames;
            std::cout << "\rProgress: " << std::fixed << std::setprecision(1) 
                      << progress << "%" << std::flush;
        }

        // Cleanup
        std::cout << "\nCleaning up resources..." << std::endl;
        reader.release();
        writer.release();
        
        std::cout << "\nVideo processing completed successfully." << std::endl;
        std::cout << "Output saved to: " << outputVideoPath << std::endl;
        return 0;
    }
    catch (const std::exception& e) {
        std::cerr << "\nUnhandled exception: " << e.what() << std::endl;
        return -1;
    }
    catch (...) {
        std::cerr << "\nUnknown error occurred" << std::endl;
        return -1;
    }
}

// Run program: Ctrl + F5 or Debug > Start Without Debugging menu
// Debug program: F5 or Debug > Start Debugging menu

// Tips for Getting Started: 
//   1. Use the Solution Explorer window to add/manage files
//   2. Use the Team Explorer window to connect to source control
//   3. Use the Output window to see build output and other messages
//   4. Use the Error List window to view errors
//   5. Go to Project > Add New Item to create new code files, or Project > Add Existing Item to add existing code files to the project
//   6. In the future, to open this project again, go to File > Open > Project and select the .sln file
