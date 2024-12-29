import '../../../../models/display_info.dart';

class ScreenInfo {
  final int handle;
  final String name;
  final int width;
  final int height;
  final bool isPrimary;

  const ScreenInfo({
    required this.handle,
    required this.name,
    required this.width,
    required this.height,
    required this.isPrimary,
  });

  factory ScreenInfo.fromDisplayInfo(DisplayInfo display) {
    return ScreenInfo(
      handle: int.tryParse(display.id) ?? 0,
      name: display.name,
      width: display.width,
      height: display.height,
      isPrimary: display.isPrimary,
    );
  }

  @override
  String toString() => '$name (${width}x$height)';
} 