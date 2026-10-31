import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/models/home_workbench_layout.dart';
import 'package:oasx/modules/home/models/resource_inventory_models.dart';
import 'package:oasx/modules/home/widgets/resource_inventory_panel.dart';
import 'package:oasx/translation/i18n.dart';

ResourceInventoryResponse sample({
  int tickets = 125,
  String day = '2026-10-31',
}) {
  Map<String, dynamic> balance(
    int quantity,
    String display, [
    bool exact = true,
  ]) => {'quantity': quantity, 'display': display, 'exact': exact};
  return ResourceInventoryResponse.fromJson({
    'dates': ['2026-10-31', '2026-10-30'],
    'schedule': {'enabled': true, 'cron': '0 23 * * *'},
    'snapshot': {
      'captured_at': '${day}T16:11:35+08:00',
      'status': 'complete',
      'resources': {
        'coins': balance(52080000, '5208万', false),
        'stamina': balance(21220, '21220'),
        'jade': balance(27080, '27080'),
        'mystery_amulets': balance(tickets, '$tickets'),
      },
    },
  });
}

Widget app(String script, ResourceInventoryLoader loader) => GetMaterialApp(
  theme: ThemeData(
    fontFamily: Platform.environment.containsKey('RESOURCE_PREVIEW_FONT')
        ? 'PreviewChinese'
        : null,
  ),
  translations: Messages(),
  locale: const Locale('zh', 'CN'),
  home: Scaffold(
    body: Center(
      child: RepaintBoundary(
        key: const ValueKey('resource-preview'),
        child: SizedBox(
          width: 340,
          height: 650,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ResourceInventoryPanel(scriptName: script, loader: loader),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = Platform.environment['RESOURCE_PREVIEW_FONT'];
    if (font != null) {
      final loader = FontLoader('PreviewChinese')
        ..addFont(
          File(font).readAsBytes().then((value) => ByteData.sublistView(value)),
        );
      await loader.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  tearDown(() => Get.reset());

  test('resource tab belongs to the right sidebar and the narrow layout', () {
    expect(
      resolveHomeWorkbenchSidebarTabs(HomeWorkbenchLayoutMode.threePane),
      contains(HomeWorkbenchTab.resources),
    );
    expect(
      resolveHomeWorkbenchTabs(HomeWorkbenchLayoutMode.singlePane),
      contains(HomeWorkbenchTab.resources),
    );
  });

  testWidgets('shows four resources and loads a retained daily snapshot', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final dates = <String?>[];
    await tester.pumpWidget(
      app('大号', (script, day) async {
        dates.add(day);
        return sample(
          tickets: day == null ? 125 : 120,
          day: day ?? '2026-10-31',
        );
      }),
    );
    await tester.pumpAndSettle();
    for (final text in ['5208万', '21,220', '27,080', '125', '普通蓝票', '不含限时蓝票']) {
      expect(find.text(text), findsOneWidget);
    }
    expect(tester.takeException(), isNull);

    final previewPath = Platform.environment['RESOURCE_PANEL_PREVIEW'];
    if (previewPath != null) {
      await tester.runAsync(() async {
        final context = tester.element(find.byType(ResourceInventoryPanel));
        for (final name in ['coins', 'stamina', 'jade', 'mystery_amulets']) {
          await precacheImage(
            AssetImage('assets/images/resources/$name.png'),
            context,
          );
        }
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('resource-preview')),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(previewPath).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.tap(find.text('最新资源'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-10-30').last);
    await tester.pumpAndSettle();
    expect(dates.last, '2026-10-30');
    expect(find.text('120'), findsOneWidget);
    expect(find.text('125'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'switching scripts ignores a late response from the previous script',
    (tester) async {
      final oldResponse = Completer<ResourceInventoryResponse>();
      Future<ResourceInventoryResponse> load(String script, String? day) =>
          script == '旧实例'
          ? oldResponse.future
          : Future.value(sample(tickets: 222));
      await tester.pumpWidget(app('旧实例', load));
      await tester.pump();
      await tester.pumpWidget(app('新实例', load));
      await tester.pumpAndSettle();
      oldResponse.complete(sample(tickets: 999));
      await tester.pumpAndSettle();
      expect(find.text('222'), findsOneWidget);
      expect(find.text('999'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
