import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nb_net/flutter_net.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/api/api_interceptor.dart';
import 'package:oasx/modules/home/widgets/action_path_card.dart';
import 'package:oasx/modules/home/widgets/log_center_panel.dart';
import 'package:oasx/modules/log/log_browser_models.dart';
import 'package:oasx/modules/log/script_log_browser_controller.dart';

class _ImageAdapter implements HttpClientAdapter {
  late ResponseBody Function(RequestOptions) respond;
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.path);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class _SilentInterceptor extends ApiInterceptor {
  @override
  void showNetErrCodeSnackBar(String msg, int code) {}
}

ScriptErrorLogDetail _detail(String id, List<ScriptErrorImageInfo> images) =>
    ScriptErrorLogDetail(
      id: id,
      directory: id,
      scriptName: 'demo',
      timestampMs: 0,
      time: '2026-10-29 09:48:31',
      legacy: false,
      log: const ScriptErrorLogText(
        fileName: 'log.txt',
        content: 'ValueError: fixture failure',
        size: 27,
        limitBytes: 1048576,
        truncated: false,
      ),
      images: images,
    );

ScriptErrorImageInfo _image(String name) => ScriptErrorImageInfo(
  name: name,
  size: 100,
  modifiedTime: '2026-10-29 09:48:30',
  url: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final temporary = Directory.systemTemp.createTempSync('oasx-image-test-');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => temporary.path,
      );
  final adapter = _ImageAdapter();
  late Uint8List png;
  late ApiClient api;
  var testIndex = 0;

  ResponseBody imageResponse() => ResponseBody.fromBytes(
    png,
    200,
    headers: {
      Headers.contentTypeHeader: ['image/png'],
    },
  );

  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 160, 90),
      Paint()..color = Colors.blue,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(160, 90);
    png = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    image.dispose();
    picture.dispose();
    final storage = GetStorage('GetStorage', temporary.path);
    await storage.initStorage;
    await storage.write('temporaryDirectory', temporary.path);
    api = ApiClient();
    NetOptions.instance.dio
      ..httpClientAdapter = adapter
      ..interceptors.removeWhere(
        (entry) => entry is ApiInterceptor || entry is DioCacheInterceptor,
      )
      ..interceptors.add(_SilentInterceptor());
  });

  setUp(() {
    api.setAddress('http://oasx-image-test-${testIndex++}.invalid');
    adapter.requests.clear();
    adapter.respond = (_) => imageResponse();
  });

  Future<void> settleImages(WidgetTester tester) async {
    await tester.pump();
    final requests = tester
        .widgetList<FutureBuilder<ScriptErrorImageBytes>>(
          find.byWidgetPredicate(
            (widget) => widget is FutureBuilder<ScriptErrorImageBytes>,
          ),
        )
        .map((widget) => widget.future!)
        .toList();
    var responsesReady = false;
    Future.wait(
      requests.map((request) async {
        try {
          await request;
        } catch (_) {
          // Failed responses are rendered by the screenshot widget.
        }
      }),
    ).then((_) => responsesReady = true);
    for (var frame = 0; frame < 20 && !responsesReady; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(responsesReady, isTrue, reason: 'Requests: ${adapter.requests}');
    await tester.pump();
    for (final element in find.byType(Image).evaluate().toList()) {
      final image = element.widget as Image;
      await tester.runAsync(() async {
        await precacheImage(image.image, element, onError: (_, _) {});
      });
    }
    await tester.pumpAndSettle();
  }

  Future<ScriptLogBrowserController> pumpDetail(
    WidgetTester tester,
    List<ScriptErrorImageInfo> images,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1100));
    final controller = ScriptLogBrowserController(scriptName: 'demo');
    controller.selectedErrorId.value = 'error-1';
    controller.selectedErrorDetail.value = _detail('error-1', images);
    final vertical = ScrollController(), horizontal = ScrollController();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      vertical.dispose();
      horizontal.dispose();
      controller.onClose();
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: LogCenterErrorDetailView(
            controller: controller,
            detailScrollController: vertical,
            detailHorizontalScrollController: horizontal,
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('错误截图'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await settleImages(tester);
    return controller;
  }

  testWidgets('screenshots replace the map and zoom without another download', (
    tester,
  ) async {
    final controller = await pumpDetail(tester, [
      _image('first.png'),
      _image('second.png'),
    ]);
    expect(find.byType(ActionPathCard), findsNothing);
    expect(find.byType(LogCenterErrorImageCard), findsNWidgets(2));
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.byIcon(Icons.download_rounded), findsNWidgets(2));
    expect(adapter.requests, [
      '/logs/errors/error-1/images/first.png',
      '/logs/errors/error-1/images/second.png',
    ]);
    controller.includeErrorTaskSettings.value = true;
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Image).first);
    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(adapter.requests, hasLength(2));
    expect(controller.exportingErrorReport.value, isFalse);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screenshot HTTP errors are visible and can be retried', (
    tester,
  ) async {
    adapter.respond = (_) => ResponseBody.fromBytes(
      utf8.encode(jsonEncode({'detail': 'fixture screenshot unavailable'})),
      404,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
    await pumpDetail(tester, [_image('retry.png')]);
    expect(find.text('截图加载失败'), findsOneWidget);
    expect(find.textContaining('HTTP 404'), findsOneWidget);
    adapter.respond = (_) => imageResponse();
    await tester.ensureVisible(find.text('重试'));
    await tester.tap(find.text('重试'));
    await settleImages(tester);
    expect(adapter.requests, hasLength(2));
    expect(find.text('截图加载失败'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching errors loads the newly selected screenshots', (
    tester,
  ) async {
    final controller = await pumpDetail(tester, [_image('first.png')]);
    controller.selectedErrorId.value = 'error-2';
    controller.selectedErrorDetail.value = _detail('error-2', [
      _image('replacement.png'),
    ]);
    await settleImages(tester);
    expect(
      adapter.requests.last,
      '/logs/errors/error-2/images/replacement.png',
    );
    expect(find.text('first.png'), findsNothing);
    expect(find.text('replacement.png'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid screenshot data shows an error on a narrow panel', (
    tester,
  ) async {
    adapter.respond = (_) => ResponseBody.fromBytes(
      utf8.encode('not a PNG'),
      200,
      headers: {
        Headers.contentTypeHeader: ['image/png'],
      },
    );
    await pumpDetail(tester, [_image('invalid.png')]);
    expect(find.text('截图加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
