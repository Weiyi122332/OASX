import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/args/index.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('settings sections keep the original group and field keys', (
    tester,
  ) async {
    final controller = Get.put(ArgsController());
    controller.loadModel({
      'settings_layout_config': [
        {
          'name': 'merged_settings_enable',
          'type': 'boolean',
          'value': true,
          'ui_hidden': true,
          'ui_layout': {
            'version': 1,
            'sections': [
              {
                'id': 'battle',
                'title': {'zh_CN': '战斗配置'},
                'variants': [
                  {
                    'id': 'high',
                    'label': {'zh_CN': '高星鬼王'},
                    'groups': [
                      {'name': 'high_star_battle_conf'},
                    ],
                  },
                ],
              },
            ],
          },
        },
      ],
      'high_star_battle_conf': [
        {
          'name': 'preset_enable',
          'type': 'boolean',
          'value': true,
          'ui_text': {
            'zh_CN': {'title': '启用预设'},
          },
        },
      ],
    });
    controller.groupsData.value = {
      for (final group in controller.groups.value) group.groupName: group,
    };
    controller.groupsName.value = controller.groupsData.value.keys.toList();
    final writes = <(String, String, dynamic)>[];
    await tester.pumpWidget(
      GetMaterialApp(
        locale: const Locale('zh', 'CN'),
        home: Scaffold(
          body: Args(
            scriptName: 'fixture',
            taskName: 'MetaDemon',
            setArgumentOverride: (_, __, group, field, ___, value) {
              writes.add((group, field, value));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('战斗配置 · 高星鬼王'), findsOneWidget);
    expect(find.text('启用预设'), findsOneWidget);
    expect(find.text('merged_settings_enable'), findsNothing);
    await tester.tap(find.byType(Checkbox));
    expect(writes, [('high_star_battle_conf', 'preset_enable', false)]);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('selecting assistance replaces the battle mode', (tester) async {
    final changes = <List<String>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiEnumDropdown(
            value: const ['鬼王战斗'],
            options: const ['鬼王战斗', '鬼王协助'],
            maxSelections: 1,
            onChanged: changes.add,
          ),
        ),
      ),
    );
    await tester.tap(find.text('鬼王战斗'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, '鬼王协助'));
    await tester.pumpAndSettle();
    expect(changes, [
      ['鬼王协助'],
    ]);
  });
}
