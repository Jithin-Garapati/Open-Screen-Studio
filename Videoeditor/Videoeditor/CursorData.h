#pragma once
#include <vector>
#include <string>
#include <fstream>
#include <nlohmann/json.hpp>

struct CursorPosition {
    double x;               // Normalized x coordinate (0-1)
    double y;               // Normalized y coordinate (0-1)
    int64_t timestamp;      // Milliseconds since start
    int cursorType;         // Windows cursor type ID
};

class CursorData {
private:
    std::vector<CursorPosition> positions;
    double videoDuration;   // Duration in milliseconds
    double fps;            // Video FPS for interpolation

public:
    CursorData() : videoDuration(0), fps(30.0) {}

    bool loadFromJson(const std::string& jsonPath) {
        try {
            std::ifstream file(jsonPath);
            if (!file.is_open()) {
                std::cerr << "Failed to open cursor data file: " << jsonPath << std::endl;
                return false;
            }

            nlohmann::json j;
            file >> j;

            positions.clear();
            const auto& posArray = j["positions"];
            for (const auto& pos : posArray) {
                CursorPosition cursorPos;
                cursorPos.x = pos["x"].get<double>();
                cursorPos.y = pos["y"].get<double>();
                cursorPos.timestamp = pos["timestamp"].get<int64_t>();
                cursorPos.cursorType = pos["cursorType"].get<int>();
                positions.push_back(cursorPos);
            }

            if (!positions.empty()) {
                videoDuration = positions.back().timestamp;
            }

            return true;
        }
        catch (const std::exception& e) {
            std::cerr << "Error loading cursor data: " << e.what() << std::endl;
            return false;
        }
    }

    void setVideoFPS(double videoFps) {
        fps = videoFps;
    }

    CursorPosition getPositionAtFrame(int frameIndex) const {
        if (positions.empty()) {
            return {0.5, 0.5, 0, 65539};  // Default center position with standard cursor
        }

        // Convert frame index to timestamp
        double timestamp = (frameIndex * 1000.0) / fps;

        // Find the positions before and after this timestamp
        auto it = std::lower_bound(positions.begin(), positions.end(), timestamp,
            [](const CursorPosition& pos, double ts) {
                return pos.timestamp < ts;
            });

        if (it == positions.begin()) {
            return positions.front();
        }
        if (it == positions.end()) {
            return positions.back();
        }

        // Get positions for interpolation
        const CursorPosition& next = *it;
        const CursorPosition& prev = *(it - 1);

        // Linear interpolation
        double t = (timestamp - prev.timestamp) / (next.timestamp - prev.timestamp);
        CursorPosition result;
        result.x = prev.x + t * (next.x - prev.x);
        result.y = prev.y + t * (next.y - prev.y);
        result.timestamp = static_cast<int64_t>(timestamp);
        result.cursorType = next.cursorType;  // Use the next cursor type

        return result;
    }

    bool hasData() const {
        return !positions.empty();
    }
}; 