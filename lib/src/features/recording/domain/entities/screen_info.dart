import '../../../../models/display_info.dart';

class ScreenInfo {
  final int handle;
  final String name;
  final int width;
  final int height;
  final bool isPrimary;
  final ScreenType type;
  final String? windowTitle; // Only for windows

  const ScreenInfo({
    required this.handle,
    required this.name,
    required this.width,
    required this.height,
    required this.isPrimary,
    this.type = ScreenType.display,
    this.windowTitle,
  });

  factory ScreenInfo.fromDisplayInfo(DisplayInfo display) {
    return ScreenInfo(
      handle: int.tryParse(display.id) ?? 0,
      name: display.name,
      width: display.width,
      height: display.height,
      isPrimary: display.isPrimary,
      type: ScreenType.display,
    );
  }

  factory ScreenInfo.fromWindow({
    required int handle,
    required String title,
    required int width,
    required int height,
  }) {
    return ScreenInfo(
      handle: handle,
      name: title,
      width: width,
      height: height,
      isPrimary: false,
      type: ScreenType.window,
      windowTitle: title,
    );
  }

  @override
  String toString() => type == ScreenType.window 
    ? '$windowTitle (${width}x$height)' 
    : '$name (${width}x$height)';
}

enum ScreenType {
  display,
  window,
} 