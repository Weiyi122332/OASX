import 'dart:ui';

class WindowStateModel {
  final double x;
  final double y;
  final double width;
  final double height;

  WindowStateModel({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory WindowStateModel.fromJson(Map<String, dynamic> json) {
    return WindowStateModel(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }
}

bool isWindowStateVisible(WindowStateModel state, Iterable<Rect> displays) {
  if (!state.x.isFinite ||
      !state.y.isFinite ||
      !state.width.isFinite ||
      !state.height.isFinite ||
      state.width <= 0 ||
      state.height <= 0) {
    return false;
  }

  final window = Rect.fromLTWH(state.x, state.y, state.width, state.height);
  return displays.any((display) {
    final overlap = window.intersect(display);
    return overlap.width >= 64 && overlap.height >= 64;
  });
}
