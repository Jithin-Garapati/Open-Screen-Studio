class CursorPosition {
  final double x;
  final double y;
  final int timestamp;
  final int cursorType; // Store the Windows cursor type ID

  const CursorPosition({
    required this.x,
    required this.y,
    required this.timestamp,
    required this.cursorType,
  });

  factory CursorPosition.fromJson(Map<String, dynamic> json) {
    return CursorPosition(
      x: json['x'] as double,
      y: json['y'] as double,
      timestamp: json['timestamp'] as int,
      cursorType: json['cursorType'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'timestamp': timestamp,
    'cursorType': cursorType,
  };
} 