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

  testWidgets('switching presets saves each group independently', (
    tester,
  ) async {
    final controller = Get.put(ArgsController());
    const groups = {'low_star_preset': '1–4 星通用', 'tsukuyomi_preset': '月读'};
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
                'id': 'quick_presets',
                'title': {'zh_CN': '快速预设'},
                'select_variant': true,
                'variants': [
                  for (final group in groups.entries)
                    {
                      'id': group.key,
                      'label': {'zh_CN': group.value},
                      'groups': [
                        {'name': group.key},
                      ],
                    },
                ],
              },
            ],
          },
        },
      ],
      for (final group in groups.keys)
        group: [
          {
            'name': 'powerful_count',
            'type': 'integer',
            'value': group == 'low_star_preset' ? 0 : 2,
            'ui_text': {
              'zh_CN': {'title': '强力追击次数'},
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

    expect(find.text('快速预设'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '3');
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('月读').last);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '5');
    final picker = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    picker.onChanged!(picker.items!.first.value);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(writes, [
      ('low_star_preset', 'powerful_count', '3'),
      ('tsukuyomi_preset', 'powerful_count', '5'),
    ]);
  });
}
