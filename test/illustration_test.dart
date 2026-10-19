import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:oasx/modules/common/models/storage_key.dart';
import 'package:oasx/modules/common/widgets/illustration_backdrop.dart';
import 'package:oasx/modules/settings/illustration_card.dart';
import 'package:oasx/service/illustration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Directory.systemTemp.createTempSync('oasx-illustration-test-');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => root.path,
      );
  var count = 0;

  Future<IllustrationService> create({
    String? directory,
    Map<StorageKey, dynamic> saved = const {},
  }) async {
    final storage = GetStorage('illustration-test-${count++}', root.path);
    await storage.initStorage;
    for (final entry in saved.entries) {
      await storage.write(entry.key.name, entry.value);
    }
    final service = IllustrationService(
      storage: storage,
      picturesDirectory: directory ?? '${root.path}/pictures-${count++}',
    );
    await service.initialize();
    return service;
  }

  Future<void> imageFile(String path, Color color) async {
    final recorder = ui.PictureRecorder();
    Canvas(
      recorder,
    ).drawRect(const Rect.fromLTWH(0, 0, 64, 64), Paint()..color = color);
    final picture = recorder.endRecording();
    final image = await picture.toImage(64, 64);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  }

  test(
    'empty directory is created; enabling stays inactive; catalog is startup-only',
    () async {
      final service = await create();
      final directory = Directory(service.directoryPath.value);
      expect(directory.existsSync(), isTrue);
      expect(directory.listSync(), isEmpty);
      expect(service.enabled.value, isFalse);
      expect(service.intervalSeconds.value, 15);
      service.setEnabled(true);
      expect(service.hasBackground, isFalse);
      await File(
        '${directory.path}/added.png',
      ).writeAsString('added after startup');
      await service.initialize();
      service.setEnabled(false);
      service.setEnabled(true);
      expect(service.pictures, isEmpty);
      service.onClose();
    },
  );

  test('scan filters extensions and restores bounded settings', () async {
    final directory = Directory('${root.path}/scan')..createSync();
    for (final name in [
      'b.PNG',
      'A.jpg',
      'c.JPEG',
      'ignored.gif',
      'ignored.txt',
    ]) {
      File('${directory.path}/$name').writeAsStringSync('catalog test');
    }
    Directory('${directory.path}/nested.png').createSync();
    final service = await create(
      directory: directory.path,
      saved: {
        StorageKey.illustrationInterval: 100,
        StorageKey.illustrationTransparency: -20,
      },
    );
    expect(service.pictures.map((path) => File(path).uri.pathSegments.last), [
      'A.jpg',
      'b.PNG',
      'c.JPEG',
    ]);
    expect(service.intervalSeconds.value, 60);
    expect(service.transparency.value, 0);
    service.setInterval(1);
    expect(service.intervalSeconds.value, 10);
    service.setTransparency(150);
    expect(service.transparency.value, 100);
    service.onClose();
  });

  testWidgets(
    'rotation uses 15 seconds, updates interval, and stops when disabled',
    (tester) async {
      final directory = Directory('${root.path}/rotate')..createSync();
      File('${directory.path}/1.jpg').writeAsStringSync('catalog test');
      File('${directory.path}/2.png').writeAsStringSync('catalog test');
      final service = (await tester.runAsync(
        () => create(directory: directory.path),
      ))!;
      service.setEnabled(true);
      await tester.pump(const Duration(seconds: 14));
      expect(service.currentIndex.value, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(service.currentIndex.value, 1);
      service.setInterval(10);
      await tester.pump(const Duration(seconds: 10));
      expect(service.currentIndex.value, 0);
      service.setEnabled(false);
      await tester.pump(const Duration(seconds: 60));
      expect(service.currentIndex.value, 0);
      service.setEnabled(true);
      service.setTransparency(100);
      await tester.pump(const Duration(seconds: 60));
      expect(service.currentIndex.value, 0);
      service.onClose();
    },
  );

  testWidgets(
    'one image does not rotate files and an empty enabled backdrop leaves the foreground usable',
    (tester) async {
      final directory = Directory('${root.path}/one')..createSync();
      File('${directory.path}/1.png').writeAsStringSync('catalog test');
      final single = (await tester.runAsync(
        () => create(directory: directory.path),
      ))!;
      single.setEnabled(true);
      await tester.pump(const Duration(seconds: 60));
      expect(single.currentIndex.value, 0);
      single.onClose();
      final empty = (await tester.runAsync(() => create()))!;
      empty.setEnabled(true);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: IllustrationBackdrop(
            service: empty,
            child: Scaffold(
              body: TextButton(
                onPressed: () => taps++,
                child: const Text('Foreground'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Foreground'));
      await tester.pump();
      expect(taps, 1);
      expect(find.byType(Image), findsNothing);
      empty.onClose();
    },
  );

  testWidgets('valid backdrop decodes and fades; corrupt images are skipped', (
    tester,
  ) async {
    final directory = Directory('${root.path}/render')..createSync();
    await tester.runAsync(() async {
      File('${directory.path}/1-broken.png').writeAsStringSync('not an image');
      await imageFile('${directory.path}/2-valid.png', Colors.blue);
    });
    final service = (await tester.runAsync(
      () => create(directory: directory.path),
    ))!;
    service.setEnabled(true);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: IllustrationBackdrop(
          service: service,
          child: Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('Readable foreground'),
              ),
            ),
          ),
        ),
      ),
    );
    // Image decoding runs on the engine; let its real work finish between frames.
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(Image).evaluate().isNotEmpty) break;
    }
    expect(service.pictures.length, 1);
    expect(service.currentPicture, endsWith('2-valid.png'));
    expect(find.byType(Image), findsOneWidget);
    final scaffold = tester.element(find.byType(Scaffold));
    expect(Theme.of(scaffold).scaffoldBackgroundColor, Colors.transparent);
    expect(find.text('Readable foreground'), findsOneWidget);
    await tester.tap(find.text('Readable foreground'));
    await tester.pump();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
    service.onClose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'settings reject out-of-range speed and persist valid integer changes',
    (tester) async {
      final service = (await tester.runAsync(() => create()))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: IllustrationSettingsCard(service: service),
            ),
          ),
        ),
      );
      expect(find.text('插画设置'), findsOneWidget);
      expect(find.text('暂无插画，当前不启用背景或轮播。'), findsOneWidget);
      final field = find.byKey(const ValueKey('illustration-interval'));
      await tester.enterText(field, '9');
      await tester.pump();
      expect(service.intervalSeconds.value, 15);
      expect(find.text('请输入 10–60 的整数'), findsOneWidget);
      await tester.enterText(field, '60');
      await tester.pump();
      expect(service.intervalSeconds.value, 60);
      expect(find.text('请输入 10–60 的整数'), findsNothing);
      service.onClose();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pan reveals both edges of wide art without cropping its height',
    (tester) async {
      final file = File('${root.path}/wide.png');
      await tester.runAsync(() => imageFile(file.path, Colors.blue));
      final bytes = file.readAsBytesSync();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 320,
              height: 160,
              child: PanningIllustration(
                image: MemoryImage(bytes),
                duration: const Duration(milliseconds: 8400),
              ),
            ),
          ),
        ),
      );
      Image image() => tester.widget<Image>(find.byType(Image));
      expect(image().fit, BoxFit.fitHeight);
      expect(image().alignment, Alignment.centerLeft);
      await tester.pump(const Duration(milliseconds: 4200));
      expect((image().alignment as Alignment).x, closeTo(0, .01));
      await tester.pump(const Duration(milliseconds: 4200));
      expect(image().alignment, Alignment.centerRight);
      final fit = applyBoxFit(
        image().fit!,
        const Size(960, 160),
        const Size(320, 160),
      );
      expect(fit.source.height, 160);
      expect(
        Alignment.centerLeft
            .inscribe(fit.source, const Rect.fromLTWH(0, 0, 960, 160))
            .left,
        0,
      );
      expect(
        Alignment.centerRight
            .inscribe(fit.source, const Rect.fromLTWH(0, 0, 960, 160))
            .right,
        960,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
