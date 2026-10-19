import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:oasx/modules/common/models/storage_key.dart';

/// Startup-only picture catalog. Settings apply immediately; files require restart.
class IllustrationService extends GetxService {
  IllustrationService({GetStorage? storage, String? picturesDirectory})
    : _storage = storage ?? GetStorage(),
      _directoryOverride = picturesDirectory;

  final GetStorage _storage;
  final String? _directoryOverride;
  final enabled = false.obs;
  final transparency = 50.obs;
  final intervalSeconds = 15.obs;
  final pictures = <String>[].obs;
  final currentIndex = 0.obs;
  final directoryPath = ''.obs;
  final loadError = ''.obs;
  Timer? _timer;
  Future<void>? _initialization;

  bool get hasBackground =>
      enabled.value && transparency.value < 100 && pictures.isNotEmpty;
  String? get currentPicture =>
      pictures.isEmpty ? null : pictures[currentIndex.value % pictures.length];

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    enabled.value = _storage.read(StorageKey.illustrationEnabled.name) == true;
    transparency.value = _boundedInt(
      _storage.read(StorageKey.illustrationTransparency.name),
      50,
      0,
      100,
    );
    intervalSeconds.value = _boundedInt(
      _storage.read(StorageKey.illustrationInterval.name),
      15,
      10,
      60,
    );
    if (kIsWeb ||
        !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }
    final directory = Directory(
      _directoryOverride ??
          '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}pictures',
    );
    directoryPath.value = directory.path;
    try {
      await directory.create(recursive: true);
      final found = <String>[];
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is File &&
            RegExp(
              r'\.(?:jpe?g|png)$',
              caseSensitive: false,
            ).hasMatch(entry.path)) {
          found.add(entry.path);
        }
      }
      found.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      pictures.assignAll(found);
    } on FileSystemException {
      loadError.value = '无法读取 pictures 文件夹，请检查文件夹的读写权限。';
    }
    _restartTimer();
  }

  void setEnabled(bool value) {
    enabled.value = value;
    _storage.write(StorageKey.illustrationEnabled.name, value);
    _restartTimer();
  }

  void setTransparency(int value) {
    transparency.value = value.clamp(0, 100);
    _storage.write(
      StorageKey.illustrationTransparency.name,
      transparency.value,
    );
    _restartTimer();
  }

  void setInterval(int value) {
    intervalSeconds.value = value.clamp(10, 60);
    _storage.write(StorageKey.illustrationInterval.name, intervalSeconds.value);
    _restartTimer();
  }

  /// Start each slide's full viewing interval after its image has decoded.
  void restartPlayback() => _restartTimer();

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    if (!hasBackground || pictures.length < 2) return;
    _timer = Timer.periodic(Duration(seconds: intervalSeconds.value), (_) {
      currentIndex.value = (currentIndex.value + 1) % pictures.length;
    });
  }

  /// Skip removed/corrupt images for this run; never rescan the directory.
  void rejectPicture(String path) {
    final index = pictures.indexOf(path);
    if (index < 0) return;
    final previous = currentPicture;
    pictures.removeAt(index);
    currentIndex.value = pictures.isEmpty
        ? 0
        : (previous != path && pictures.contains(previous)
              ? pictures.indexOf(previous!)
              : index % pictures.length);
    _restartTimer();
  }

  static int _boundedInt(dynamic value, int fallback, int min, int max) {
    final parsed = value is num
        ? (value.isFinite ? value.round() : fallback)
        : int.tryParse('$value');
    return (parsed ?? fallback).clamp(min, max);
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
