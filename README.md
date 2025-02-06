# OpenScreen Studio

An opinionated screen recording and editing app for Windows built with Flutter Desktop and C++.

## Features

- Automatic zooming on cursor actions
- Smooth cursor animation
- Adjustable cursor sizes and colors
- Vertical/horizontal exports for social media
- Custom cursor overlay during recording
- Advanced post-recording effects
  - Cursor smoothing
  - Size adjustment
  - Cursor hiding
  - Looping
- Intuitive editor for:
  - Manual/automatic zoom
  - Background styling
  - Spacing adjustments
  - Cut/speed-up features

## Requirements

### Frontend (Flutter)
- Flutter SDK 3.0 or higher
- Dart SDK 2.17 or higher
- Windows 10 or higher

### Backend (C++)
- Visual Studio 2022 with C++ Desktop Development
- OpenCV 4.1.0 or higher
- CMake 3.15 or higher
- Windows SDK 10.0 or higher

## Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/OpenScreenStudio.git
cd OpenScreenStudio
```

2. Install Flutter dependencies:
```bash
flutter pub get
```

3. Build C++ backend:
```bash
cd Videoeditor
build.bat
```

4. Run the app:
```bash
flutter run -d windows
```

## Project Structure

```
lib/                    # Flutter frontend code
├── screens/           # UI screens
├── widgets/           # Reusable widgets
├── models/            # Data models
├── controllers/       # State management
├── services/          # Platform services
└── utils/            # Helper functions

Videoeditor/           # C++ backend code
├── Videoeditor/      # Core processing code
├── include/          # Header files
└── cursors/          # Cursor assets
```

## Building for Release

1. Build the C++ backend in Release mode:
```bash
cd Videoeditor
build.bat Release
```

2. Build Flutter app:
```bash
flutter build windows
```

The release build will be available in `build/windows/runner/Release/`.

## Development

### Frontend Development
- Use `flutter run -d windows` for development
- Hot reload is supported
- State management with Riverpod
- UI components follow Material Design 3

### Backend Development
- Open `Videoeditor.sln` in Visual Studio 2022
- Build using Visual Studio or `build.bat`
- OpenCV is required for video processing
- Cursor overlay system uses Windows API

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- OpenCV for video processing
- Flutter team for Windows support
- Contributors and testers
