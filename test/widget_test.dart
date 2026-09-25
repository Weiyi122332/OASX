import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/modules/settings/widgets/setting_item.dart';

void main() {
  Future<void> pumpSettingItem(WidgetTester tester, double width) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: const SettingItem(
                left: Text('Server address'),
                right: SizedBox(width: 220, child: TextField()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('setting item stacks a fixed-width input on a phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSettingItem(tester, 280);

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byType(TextField)).dy,
      greaterThan(tester.getTopLeft(find.text('Server address')).dy),
    );
  });

  testWidgets('setting item keeps a row on a wide layout', (tester) async {
    await pumpSettingItem(tester, 700);

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byType(TextField)).dx,
      greaterThan(tester.getTopLeft(find.text('Server address')).dx),
    );
  });
}
