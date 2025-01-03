# OpenScreen Studio

An opinionated screen recording and editing app for Windows built with Flutter Desktop.

## Features

- Screen recording with automatic cursor tracking
- Advanced cursor effects (smoothing, size adjustment, hiding)
- Automatic zooming on cursor actions
- Manual zoom layers with customizable settings
- Background customization with colors and rounded corners
- Timeline-based editing with multiple layer types
- Export to various formats (16:9, 9:16, 1:1, GIF)

## Requirements

- Windows 10 or later
- Flutter SDK (>=3.0.0)
- Visual Studio Build Tools
- Git

## Development Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/open_screen_studio.git
cd open_screen_studio
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run -d windows
```

## Building

To create a release build:

```bash
flutter build windows
```

The built application will be available in `build/windows/runner/Release/`.

## Project Structure

```
lib/
├── src/
│   ├── features/          # Feature modules
│   │   ├── background/    # Background customization
│   │   ├── recording/     # Screen recording
│   │   ├── timeline/      # Timeline editing
│   │   └── zoom/          # Zoom functionality
│   ├── screens/          # App screens
│   ├── widgets/          # Reusable widgets
│   ├── models/           # Data models
│   ├── providers/        # State management
│   ├── services/         # Platform services
│   └── utils/           # Helper functions
└── main.dart            # App entry point
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
