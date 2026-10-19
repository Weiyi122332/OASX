import 'package:oasx/translation/i18n.dart';

/// Canonical names keep upper-case logger headings translatable in the UI.
final _taskNames = <String, String>{
  for (final key in Messages().all_cn_translate.keys)
    key.replaceAll(RegExp(r'[\s_]'), '').toUpperCase(): key,
};

String _canonicalTask(String value) =>
    _taskNames[value.replaceAll(RegExp(r'[\s_]'), '').toUpperCase()] ?? value;

/// Tracks only level-0 task headings, not battle/page subheadings.
/// save_error_log keeps the final separator plus the preceding two lines,
/// so these headings survive even when scheduler/[Task] messages are omitted.
class LogTaskContext {
  String? task;
  String? fallbackTask;
  bool _separator = false;
  String? _heading;

  void consume(String line) {
    final explicit = RegExp(
      r'\[Task\]\s+(\w+)\s+\(|Scheduler: Start task `([^`]+)`',
    ).firstMatch(line);
    if (explicit != null) {
      task = _canonicalTask(explicit.group(1) ?? explicit.group(2)!);
    }
    final trimmed = line.trim();
    if (RegExp(r'^═{15,}$').hasMatch(trimmed)) {
      if (_heading != null) {
        task = _heading!.toUpperCase() == 'START'
            ? null
            : _canonicalTask(_heading!);
      }
      _heading = null;
      _separator = true;
      return;
    }
    final title = RegExp(r'^─{10,}\s*(.*?)\s*─{10,}$').firstMatch(trimmed);
    _heading = _separator ? title?.group(1)?.trim() : null;
    _separator = false;
    // Tracebacks and module_path survive in some older saved error formats.
    if (line.contains('module_path:') || line.trimLeft().startsWith('File ')) {
      final path = RegExp(
        r'tasks[/\\]([^/\\]+)[/\\]script_task\.py',
      ).firstMatch(line);
      if (path != null) fallbackTask = _canonicalTask(path.group(1)!);
    }
  }
}
