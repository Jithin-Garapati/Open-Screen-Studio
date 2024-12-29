class DisplayInfo {
  final String id;
  final String name;
  final int width;
  final int height;
  final int x;
  final int y;
  final bool isPrimary;

  const DisplayInfo({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.x,
    required this.y,
    this.isPrimary = false,
  });

  DisplayInfo copyWith({
    String? id,
    String? name,
    int? width,
    int? height,
    int? x,
    int? y,
    bool? isPrimary,
  }) {
    return DisplayInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      width: width ?? this.width,
      height: height ?? this.height,
      x: x ?? this.x,
      y: y ?? this.y,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  @override
  String toString() => 'DisplayInfo(id: $id, name: $name, width: $width, height: $height, x: $x, y: $y, isPrimary: $isPrimary)';
} 