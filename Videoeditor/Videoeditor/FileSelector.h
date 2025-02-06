#pragma once
#include <string>
#include <windows.h>
#include <shobjidl.h>

class FileSelector {
public:
    enum class FileType {
        Video,
        JSON,
        Any
    };
    
    // Helper function to convert wstring to string
    static std::string wstring_to_string(const std::wstring& wstr);

    // Main file dialog function that returns a regular string
    static std::string showFileDialog(FileType type = FileType::Any);

private:
    // Internal function that handles the Windows API calls
    static std::wstring showFileDialogW(FileType type = FileType::Any);
}; 