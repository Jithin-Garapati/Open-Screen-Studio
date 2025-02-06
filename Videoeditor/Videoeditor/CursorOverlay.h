#pragma once
#include <opencv2/opencv.hpp>
#include <string>
#include <unordered_map>
#include <filesystem>
#include <algorithm>
#include <fstream>
#include <sstream>
#include "ZoomConfig.h"

// Define this in exactly one source file before including nanosvg headers
#define NANOSVG_IMPLEMENTATION
#define NANOSVGRAST_IMPLEMENTATION
#include "nanosvg/nanosvg.h"
#include "nanosvg/nanosvgrast.h"

class CursorOverlay {
private:
    std::unordered_map<int, cv::Mat> cursors;      // Cursor images for each type
    std::unordered_map<int, cv::Mat> alphas;       // Alpha channels for each type
    std::unordered_map<int, cv::Size> sizes;       // Original sizes for each cursor type
    bool isLoaded;
    const int TARGET_HEIGHT = 128;  // Increased base height for better scaling
    CursorSettings settings;       // Current cursor settings

    cv::Mat loadSvg(const std::string& path, int targetHeight) {
        NSVGimage* image = nsvgParseFromFile(path.c_str(), "px", 96.0f);
        if (!image) {
            std::cerr << "Error loading SVG file: " << path << std::endl;
            return cv::Mat();
        }

        // Calculate scale to match target height while preserving aspect ratio
        float scale = targetHeight / image->height;
        int width = static_cast<int>(std::ceil(image->width * scale));
        int height = static_cast<int>(std::ceil(image->height * scale));

        // Create rasterizer and allocate buffer
        NSVGrasterizer* rast = nsvgCreateRasterizer();
        if (!rast) {
            std::cerr << "Could not create rasterizer for: " << path << std::endl;
            nsvgDelete(image);
            return cv::Mat();
        }

        // Allocate memory for image
        unsigned char* buffer = new unsigned char[width * height * 4];
        
        // Rasterize with proper scale and offset
        nsvgRasterize(rast, image, 0, 0, scale, buffer, width, height, width * 4);

        // Create OpenCV Mat and copy data
        cv::Mat result(height, width, CV_8UC4);
        memcpy(result.data, buffer, width * height * 4);

        // Clean up
        delete[] buffer;
        nsvgDeleteRasterizer(rast);
        nsvgDelete(image);

        return result;
    }

    cv::Mat normalizeSize(const cv::Mat& img) {
        double scale = static_cast<double>(TARGET_HEIGHT) / img.rows;
        cv::Mat resized;
        // Use area interpolation for downscaling
        if (scale < 1.0) {
            cv::resize(img, resized, cv::Size(), scale, scale, cv::INTER_AREA);
        } else {
            // Use Lanczos for upscaling
            cv::resize(img, resized, cv::Size(), scale, scale, cv::INTER_LANCZOS4);
        }
        return resized;
    }

    cv::Mat applyTint(const cv::Mat& cursor, uint32_t tintColor) {
        // Extract ARGB components
        double alpha = ((tintColor >> 24) & 0xFF) / 255.0;
        double red = ((tintColor >> 16) & 0xFF) / 255.0;
        double green = ((tintColor >> 8) & 0xFF) / 255.0;
        double blue = (tintColor & 0xFF) / 255.0;

        cv::Mat tinted = cursor.clone();
        for (int i = 0; i < cursor.rows; i++) {
            for (int j = 0; j < cursor.cols; j++) {
                cv::Vec3b& pixel = tinted.at<cv::Vec3b>(i, j);
                // Apply tint while preserving luminance
                double luminance = (0.299 * pixel[2] + 0.587 * pixel[1] + 0.114 * pixel[0]) / 255.0;
                pixel[0] = cv::saturate_cast<uchar>(luminance * blue * 255);   // B
                pixel[1] = cv::saturate_cast<uchar>(luminance * green * 255);  // G
                pixel[2] = cv::saturate_cast<uchar>(luminance * red * 255);    // R
            }
        }
        return tinted;
    }

    bool loadCursor(const std::string& path, int cursorType) {
        cv::Mat img;
        // Get file extension
        std::string ext = std::filesystem::path(path).extension().string();
        std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
        
        if (ext == ".svg") {
            // Try to load SVG first
            img = loadSvg(path, TARGET_HEIGHT);
            
            // If SVG loading fails, try corresponding PNG
            if (img.empty()) {
                std::string pngPath = std::filesystem::path(path).parent_path().string() + "\\";
                switch(cursorType) {
                    case 32512: // IDC_ARROW (Standard arrow)
                        pngPath += "cursor_normal.png";
                        break;
                    case 32515: // IDC_IBEAM (Text I-beam)
                        pngPath += "cursor_text.png";
                        break;
                    case 32513: // IDC_HAND (Hand pointer)
                        pngPath += "cursor_pointer.png";
                        break;
                    case 32644: // IDC_SIZEWE (Horizontal resize)
                        pngPath += "cursor_resize_horizontal.png";
                        break;
                    case 32645: // IDC_SIZENS (Vertical resize)
                        pngPath += "cursor_resize_vertical.png";
                        break;
                    default:
                        pngPath += "cursor_normal.png";
                }
                img = cv::imread(pngPath, cv::IMREAD_UNCHANGED);
                if (!img.empty()) {
                    std::cout << "Successfully loaded fallback PNG: " << pngPath << std::endl;
                }
            }
        } else {
            img = cv::imread(path, cv::IMREAD_UNCHANGED);
        }

        if (img.empty() || img.channels() != 4) {
            return false;
        }

        // Print original size for debugging
        std::cout << "Original cursor size for type " << cursorType << ": " 
                  << img.cols << "x" << img.rows << std::endl;

        // Normalize size while maintaining aspect ratio
        cv::Mat normalizedImg = normalizeSize(img);
        
        // Print normalized size for debugging
        std::cout << "Normalized cursor size: " 
                  << normalizedImg.cols << "x" << normalizedImg.rows << std::endl;

        std::vector<cv::Mat> channels;
        cv::split(normalizedImg, channels);
        
        std::vector<cv::Mat> bgr = { channels[0], channels[1], channels[2] };
        cv::Mat cursor;
        cv::merge(bgr, cursor);
        
        cursors[cursorType] = cursor;
        alphas[cursorType] = channels[3];
        sizes[cursorType] = cursor.size();
        return true;
    }

public:
    CursorOverlay() : isLoaded(false) {
        settings.size = 1.0;
        settings.opacity = 1.0;
        settings.hasTint = false;
    }

    void setSettings(const CursorSettings& newSettings) {
        settings = newSettings;
    }

    bool loadCursors(const std::string& cursorDir) {
        std::filesystem::path dir(cursorDir);
        if (!std::filesystem::exists(dir)) {
            std::filesystem::create_directories(dir);
        }

        // Updated cursor type mappings to match JSON values
        std::map<int, std::string> cursorFiles = {
            {65539, "default.svg"},             // Normal arrow cursor (0)
            {65541, "textcursor.svg"},          // Text cursor / I-beam (1)
            {65567, "handpointing.svg"},        // Hand pointer (2)
            {65551, "resizenorthsouth.svg"},    // Vertical resize (4)
            {65569, "resizeleftright.svg"}      // Horizontal resize (5)
        };

        std::cout << "\nLoading and normalizing cursors..." << std::endl;
        bool allLoaded = true;
        for (const auto& [type, filename] : cursorFiles) {
            std::string path = (dir / filename).string();
            if (!loadCursor(path, type)) {
                std::cerr << "Failed to load cursor: " << path << std::endl;
                allLoaded = false;
            }
        }
        std::cout << "Cursor loading complete.\n" << std::endl;

        isLoaded = allLoaded;
        return isLoaded;
    }

    void overlay(cv::Mat& frame, int x, int y, int cursorType = 65541, double scale = 1.0) {
        if (!isLoaded || cursors.find(cursorType) == cursors.end()) {
            cursorType = 65541;  // Fallback to normal arrow cursor
            if (!isLoaded || cursors.find(cursorType) == cursors.end()) {
                return;
            }
        }

        // Get original cursor and alpha
        cv::Mat cursor = cursors[cursorType].clone();
        cv::Mat alpha = alphas[cursorType].clone();
        const cv::Size& originalSize = sizes[cursorType];

        // Apply tint if enabled
        if (settings.hasTint) {
            cursor = applyTint(cursor, settings.tintColor);
        }

        // Calculate final scale (combining base scale and settings scale)
        double finalScale = scale * settings.size;
        
        // Calculate scaled size
        int scaledWidth = static_cast<int>(originalSize.width * finalScale);
        int scaledHeight = static_cast<int>(originalSize.height * finalScale);
        
        // Ensure minimum size
        scaledWidth = std::max<int>(scaledWidth, 16);
        scaledHeight = std::max<int>(scaledHeight, 16);

        // Resize cursor and alpha if scale is not 1.0
        if (std::abs(finalScale - 1.0) > 0.001) {
            // Use area interpolation for downscaling
            if (finalScale < 1.0) {
                cv::resize(cursor, cursor, cv::Size(scaledWidth, scaledHeight), 0, 0, cv::INTER_AREA);
                cv::resize(alpha, alpha, cv::Size(scaledWidth, scaledHeight), 0, 0, cv::INTER_AREA);
            } else {
                // Use Lanczos for upscaling
                cv::resize(cursor, cursor, cv::Size(scaledWidth, scaledHeight), 0, 0, cv::INTER_LANCZOS4);
                cv::resize(alpha, alpha, cv::Size(scaledWidth, scaledHeight), 0, 0, cv::INTER_LANCZOS4);
            }
        }

        // Apply cursor offset (move slightly up and left)
        x -= static_cast<int>(scaledWidth * 0.3);  // Move left by 20% of cursor width
        y -= static_cast<int>(scaledHeight * 0.3); // Move up by 20% of cursor height

        // Ensure coordinates are within frame
        if (x < 0) x = 0;
        if (y < 0) y = 0;
        if (x + scaledWidth > frame.cols) x = frame.cols - scaledWidth;
        if (y + scaledHeight > frame.rows) y = frame.rows - scaledHeight;

        // Get ROI in the frame
        cv::Mat roi = frame(cv::Rect(x, y, scaledWidth, scaledHeight));

        // Overlay cursor using alpha blending with opacity
        for (int i = 0; i < scaledHeight; i++) {
            for (int j = 0; j < scaledWidth; j++) {
                uchar a = alpha.at<uchar>(i, j);
                if (a > 0) {
                    cv::Vec3b& pixel = roi.at<cv::Vec3b>(i, j);
                    cv::Vec3b cursor_pixel = cursor.at<cv::Vec3b>(i, j);
                    
                    float alpha_f = (a / 255.0f) * settings.opacity;
                    pixel[0] = pixel[0] * (1 - alpha_f) + cursor_pixel[0] * alpha_f;
                    pixel[1] = pixel[1] * (1 - alpha_f) + cursor_pixel[1] * alpha_f;
                    pixel[2] = pixel[2] * (1 - alpha_f) + cursor_pixel[2] * alpha_f;
                }
            }
        }
    }

    bool isInitialized() const {
        return isLoaded;
    }
}; 