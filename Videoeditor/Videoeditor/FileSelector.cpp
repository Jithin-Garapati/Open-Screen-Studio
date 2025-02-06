#include "FileSelector.h"

std::string FileSelector::wstring_to_string(const std::wstring& wstr) {
    if (wstr.empty()) return "";
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string str(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &str[0], size_needed, NULL, NULL);
    return str;
}

std::string FileSelector::showFileDialog(FileType type) {
    return wstring_to_string(showFileDialogW(type));
}

std::wstring FileSelector::showFileDialogW(FileType type) {
    HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
    if (FAILED(hr))
        return L"";

    IFileOpenDialog *pFileOpen;
    hr = CoCreateInstance(CLSID_FileOpenDialog, NULL, CLSCTX_ALL, 
                        IID_IFileOpenDialog, reinterpret_cast<void**>(&pFileOpen));

    if (SUCCEEDED(hr)) {
        // Set file type filter based on type
        COMDLG_FILTERSPEC fileTypes[3] = {};
        UINT filterCount = 0;

        switch(type) {
            case FileType::Video:
                fileTypes[0] = { L"Video Files", L"*.mp4;*.avi;*.mkv;*.mov" };
                fileTypes[1] = { L"All Files", L"*.*" };
                filterCount = 2;
                break;
            case FileType::JSON:
                fileTypes[0] = { L"JSON Files", L"*.json" };
                fileTypes[1] = { L"All Files", L"*.*" };
                filterCount = 2;
                break;
            case FileType::Any:
                fileTypes[0] = { L"All Files", L"*.*" };
                filterCount = 1;
                break;
        }

        pFileOpen->SetFileTypes(filterCount, fileTypes);

        // Show the dialog
        hr = pFileOpen->Show(NULL);

        if (SUCCEEDED(hr)) {
            IShellItem *pItem;
            hr = pFileOpen->GetResult(&pItem);
            if (SUCCEEDED(hr)) {
                PWSTR filePath;
                hr = pItem->GetDisplayName(SIGDN_FILESYSPATH, &filePath);
                if (SUCCEEDED(hr)) {
                    std::wstring result(filePath);
                    CoTaskMemFree(filePath);
                    pItem->Release();
                    pFileOpen->Release();
                    CoUninitialize();
                    return result;
                }
                pItem->Release();
            }
        }
        pFileOpen->Release();
    }
    CoUninitialize();
    return L"";
} 