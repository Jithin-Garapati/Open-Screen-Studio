
enum CursorType {
  normal('cursor_normal.png'),
  pointer('cursor_pointer.png'),
  text('cursor_text.png'),
  resizeHorizontal('cursor_resize_horizontal.png'),
  resizeVertical('cursor_resize_vertical.png');

  final String assetPath;
  const CursorType(this.assetPath);

  String get fullAssetPath => 'assets/cursors/$assetPath';
} 