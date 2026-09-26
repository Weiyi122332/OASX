import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/modules/common/models/window_state.dart';

void main() {
  final displays = [
    const Rect.fromLTWH(0, 0, 1920, 1080),
    const Rect.fromLTWH(-1280, 0, 1280, 1024),
  ];

  test('restores a visible window on either display', () {
    expect(
      isWindowStateVisible(
        WindowStateModel(x: 100, y: 100, width: 1200, height: 800),
        displays,
      ),
      isTrue,
    );
    expect(
      isWindowStateVisible(
        WindowStateModel(x: -900, y: 100, width: 600, height: 500),
        displays,
      ),
      isTrue,
    );
  });

  test('rejects the off-screen coordinates observed on Windows', () {
    expect(
      isWindowStateVisible(
        WindowStateModel(
          x: -21333.333333333332,
          y: -21333.333333333332,
          width: 260,
          height: 420,
        ),
        displays,
      ),
      isFalse,
    );
  });

  test('rejects a window with no usable visible area', () {
    expect(
      isWindowStateVisible(
        WindowStateModel(x: 1900, y: 100, width: 300, height: 400),
        displays,
      ),
      isFalse,
    );
  });
}
