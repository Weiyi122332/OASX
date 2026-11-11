import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/args/index.dart';

class _ReloadingArgsController extends ArgsController {
  final revision = ValueNotifier(0);

  @override
  Future<bool> saveDraftChanges() async {
    dirtyFieldKeys.clear();
    revision.value++;
    return true;
  }

  @override
  void onClose() {
    revision.dispose();
    super.onClose();
  }
}

void _loadPresetArguments(
  ArgsController controller, {
  bool withRental = false,
}) {
  const groups = {'low_star_preset': '1–4 星通用', 'tsukuyomi_preset': '月读'};
  const rentalChoices = {
    'meta_demon_rental_none': '不使用',
    'meta_demon_rental_group': '群体',
    'meta_demon_rental_single': '单体',
    'meta_demon_rental_normal_attack': '普攻',
  };
  const personalOnly = {'rental_lineup': 'meta_demon_rental_none'};
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
        if (withRental) ...[
          {
            'name': 'rental_lineup',
            'type': 'enum',
            'value': 'meta_demon_rental_none',
            'enumEnum': rentalChoices.keys.toList(),
            'ui_text': {
              'zh_CN': {'title': '使用租借阵容', 'options': rentalChoices},
            },
          },
          {
            'name': 'switch_soul',
            'type': 'boolean',
            'value': true,
            'ui_visible_when': personalOnly,
          },
          {
            'name': 'preset_numbers',
            'type': 'string',
            'value': '1,1',
            'ui_visible_when': personalOnly,
          },
        ],
      ],
  });
  controller.groupsData.value = {
    for (final group in controller.groups.value) group.groupName: group,
  };
  controller.groupsName.value = controller.groupsData.value.keys.toList();
}

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
    _loadPresetArguments(controller);
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

  testWidgets('saving keeps the selected preset after settings reload', (
    tester,
  ) async {
    final controller = _ReloadingArgsController();
    Get.put<ArgsController>(controller);
    _loadPresetArguments(controller);
    await tester.pumpWidget(
      GetMaterialApp(
        locale: const Locale('zh', 'CN'),
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: controller.revision,
            builder: (context, revision, _) => Args(
              key: ValueKey(revision),
              scriptName: 'fixture',
              taskName: 'MetaDemon',
              stagingMode: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dropdown = find.byType(DropdownButton<String>);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('月读').last);
    await tester.pumpAndSettle();
    controller.stageArgumentChange(
      'tsukuyomi_preset',
      'powerful_count',
      '5',
      'integer',
    );
    await tester.pump();
    await tester.tap(
      find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    await tester.pumpAndSettle();

    expect(controller.revision.value, 1);
    expect(
      tester.widget<DropdownButton<String>>(dropdown).value,
      'quick_presets-tsukuyomi_preset',
    );
    expect(find.text('5'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('selecting a rental hides personal settings in that preset', (
    tester,
  ) async {
    final controller = Get.put(ArgsController());
    _loadPresetArguments(controller, withRental: true);
    controller.isDraftMode.value = true;
    await tester.pumpWidget(
      const GetMaterialApp(
        locale: Locale('zh', 'CN'),
        home: Scaffold(
          body: Args(scriptName: 'fixture', taskName: 'MetaDemon'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.drag_indicator_outlined), findsNothing);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('1,1'), findsOneWidget);

    final rental = find.byType(DropdownButtonFormField<String>);
    await tester.tap(rental);
    await tester.pumpAndSettle();
    await tester.tap(find.text('群体').last);
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('1,1'), findsNothing);
    expect(
      controller.findArgument('low_star_preset', 'rental_lineup')?.value,
      'meta_demon_rental_group',
    );
    expect(
      controller.findArgument('tsukuyomi_preset', 'rental_lineup')?.value,
      'meta_demon_rental_none',
    );

    await tester.tap(rental);
    await tester.pumpAndSettle();
    await tester.tap(find.text('不使用').last);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect(find.text('1,1'), findsOneWidget);
  });
}
