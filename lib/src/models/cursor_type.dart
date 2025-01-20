import 'package:flutter/foundation.dart';

enum CursorType {
  normal(65539, 'cursor_normal.png'),
  text(65541, 'cursor_text.png'),
  hand(65567, 'cursor_hand.png'),
  resizeHorizontal(65569, 'cursor_resize_horizontal.png'),
  resizeVertical(65551, 'cursor_resize_vertical.png');

  final int value;
  final String assetName;

  const CursorType(this.value, this.assetName);

  String get fullAssetPath => 'assets/cursors/$assetName';

  static CursorType fromValue(int value) {
    debugPrint('Converting cursor value: $value');
    return values.firstWhere(
      (type) => type.value == value,
      orElse: () => CursorType.normal,
    );
  }
}