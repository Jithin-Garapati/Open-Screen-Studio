@echo off
setlocal enabledelayedexpansion

:: Default to Debug if no build type specified
set BUILD_TYPE=Debug
if not "%1"=="" set BUILD_TYPE=%1

:: Configuration
set OPENCV_DIR=C:\Program Files\opencv
set OPENCV_VERSION=4100
set VS_PATH=C:\Program Files\Microsoft Visual Studio\2022\Community

:: Validate OpenCV installation
if not exist "%OPENCV_DIR%\build\include" (
    echo Error: OpenCV not found at %OPENCV_DIR%
    echo Please install OpenCV or update OPENCV_DIR in this script
    exit /b 1
)

echo Building in %BUILD_TYPE% mode...

:: Stop any running instances
echo Stopping any running instances...
taskkill /F /IM Videoeditor.exe 2>nul
timeout /t 1 /nobreak >nul

:: Clean up old files
echo Cleaning up old files...
if exist "x64\%BUILD_TYPE%\Videoeditor.exe" del /F /Q "x64\%BUILD_TYPE%\Videoeditor.exe"
if exist "x64\%BUILD_TYPE%\Videoeditor.ilk" del /F /Q "x64\%BUILD_TYPE%\Videoeditor.ilk"
if exist "x64\%BUILD_TYPE%\Videoeditor.pdb" del /F /Q "x64\%BUILD_TYPE%\Videoeditor.pdb"

:: Create directories
echo Creating directories...
if not exist "x64" mkdir "x64"
if not exist "x64\%BUILD_TYPE%" mkdir "x64\%BUILD_TYPE%"

:: Set up Visual Studio environment
call "%VS_PATH%\Common7\Tools\VsDevCmd.bat" -arch=amd64

:: Set build-specific flags
if /I "%BUILD_TYPE%"=="Debug" (
    set RUNTIME_FLAG=/MDd
    set DEBUG_FLAG=/D "_DEBUG"
    set OPENCV_SUFFIX=d
) else (
    set RUNTIME_FLAG=/MD
    set DEBUG_FLAG=/D "NDEBUG"
    set OPENCV_SUFFIX=
)

echo Building Videoeditor in %BUILD_TYPE% mode...
echo Current directory: %CD%

echo.
echo Building with cl.exe...
cl.exe /Zi /EHsc /nologo %RUNTIME_FLAG% /std:c++17 /arch:AVX2 ^
    %DEBUG_FLAG% ^
    /D "_CONSOLE" ^
    /D "_UNICODE" ^
    /D "UNICODE" ^
    /Fe:x64\%BUILD_TYPE%\Videoeditor.exe ^
    Videoeditor\Videoeditor.cpp ^
    Videoeditor\FileSelector.cpp ^
    /I"%OPENCV_DIR%\build\include" ^
    /I"%OPENCV_DIR%\build\include\opencv2" ^
    /I".\include" ^
    /link ^
    /DEBUG:FULL ^
    /MACHINE:X64 ^
    /SUBSYSTEM:CONSOLE ^
    /LIBPATH:"%OPENCV_DIR%\build\x64\vc16\lib" ^
    opencv_world%OPENCV_VERSION%%OPENCV_SUFFIX%.lib ^
    ole32.lib ^
    oleaut32.lib ^
    ucrt%OPENCV_SUFFIX%.lib ^
    vcruntime%OPENCV_SUFFIX%.lib ^
    msvcrt%OPENCV_SUFFIX%.lib

if %ERRORLEVEL% EQU 0 (
    echo Build successful!
    
    :: Copy OpenCV DLLs
    echo Copying OpenCV DLLs...
    copy /Y "%OPENCV_DIR%\build\x64\vc16\bin\opencv_world%OPENCV_VERSION%%OPENCV_SUFFIX%.dll" "x64\%BUILD_TYPE%\"
    copy /Y "%OPENCV_DIR%\build\x64\vc16\bin\opencv_videoio_ffmpeg%OPENCV_VERSION%_64.dll" "x64\%BUILD_TYPE%\"
    copy /Y "%OPENCV_DIR%\build\x64\vc16\bin\opencv_videoio_msmf%OPENCV_VERSION%_64%OPENCV_SUFFIX%.dll" "x64\%BUILD_TYPE%\"
    
    :: Copy to Flutter app directory if it exists
    set FLUTTER_BUILD_DIR=..\build\windows\runner\%BUILD_TYPE%
    if exist "!FLUTTER_BUILD_DIR!" (
        echo Copying files to Flutter build directory...
        copy /Y "x64\%BUILD_TYPE%\Videoeditor.exe" "!FLUTTER_BUILD_DIR!\"
        copy /Y "x64\%BUILD_TYPE%\*.dll" "!FLUTTER_BUILD_DIR!\"
    ) else (
        echo Flutter build directory not found at !FLUTTER_BUILD_DIR!
        echo Please build the Flutter app first
    )
    
    echo.
    echo Build artifacts are in x64\%BUILD_TYPE%
) else (
    echo Build failed with error %ERRORLEVEL%
)

endlocal
pause 