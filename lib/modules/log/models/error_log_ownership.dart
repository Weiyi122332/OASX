import 'dart:convert';

import 'package:oasx/modules/log/log_browser_models.dart';

/// Task names identify actions, not the config that ran them.
/// Only explicit config/scheduler/process identity is used as ownership evidence.
String? inferErrorLogScriptName(String text, {bool truncated = false}) {
  if (truncated) return null;
  final names = <String>{};
  final patterns = [
    RegExp(r'^Start scheduler loop:\s*(.+?)\s*$'),
    RegExp(r'^\[(?:Config|ConfigName)\]\s+(.+?)\s*$'),
    RegExp(r'^Script (.+?) (?:process exit|received signal\b.*)\s*$'),
    RegExp(
      r'^(?:config_name|Config name)\s*[:=]\s*["\x27]?([^"\x27]+?)["\x27]?\s*$',
    ),
  ];
  for (final line in const LineSplitter().convert(text)) {
    final message = line.contains('|')
        ? line.substring(line.lastIndexOf('|') + 1).trim()
        : line.trim();
    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final name = match.group(1)!.trim();
        if (name.isNotEmpty &&
            !RegExp(r'[/\\<>:"|?*\x00-\x1f]').hasMatch(name)) {
          names.add(name);
        }
      }
    }
  }
  return names.length == 1 ? names.single : null;
}

class ErrorLogOwnershipResolver {
  final _owners = <String, Future<String?>>{};

  Future<ScriptErrorLogItem> resolve(
    ScriptErrorLogItem item, {
    required String backend,
    required Future<ScriptErrorLogDetail> Function(String id) loadDetail,
  }) async {
    if (item.scriptName?.isNotEmpty == true) return item;
    final key = '$backend|${item.id}|${item.logSize}';
    if (_owners.length >= 256 && !_owners.containsKey(key)) {
      _owners.remove(_owners.keys.first);
    }
    final future = _owners.putIfAbsent(key, () async {
      final detail = await loadDetail(item.id);
      return detail.scriptName?.isNotEmpty == true
          ? detail.scriptName
          : inferErrorLogScriptName(
              detail.log.content,
              truncated: detail.log.truncated,
            );
    });
    try {
      return item.withScriptName(await future);
    } catch (_) {
      // Failures must stay visible and retryable, never become "unknown owner".
      _owners.remove(key);
      rethrow;
    }
  }
}

/// Preserve unresolved entries separately; never label them as the current config.
bool errorLogBelongsInView(ScriptErrorLogItem item, String scriptName) =>
    item.scriptName == null ||
    item.scriptName == scriptName ||
    (!item.legacy && item.scriptName == scriptName.split('_').first);
