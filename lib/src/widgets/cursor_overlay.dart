import 'package:flutter/material.dart';

class CursorOverlay extends StatelessWidget {
  final String cursorType;
  
  const CursorOverlay({
    super.key,
    this.cursorType = 'normal',
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/cursors/cursor_$cursorType.png',
      width: 32,
      height: 32,
      filterQuality: FilterQuality.medium,
    );
  }
} 