import 'package:oasx/translation/i18n.dart';

/// Canonical names keep upper-case logger headings translatable in the UI.
final _taskNames = <String, String>{
  for (final key in Messages().all_cn_translate.keys)
    key.replaceAll(RegExp(r'[\s_]'), '').toUpperCase(): key,
};

String _canonicalTask(String value) =>
    _taskNames[value.replaceAll(RegExp(r'[\s_]'), '').toUpperCase()] ?? value;

/// Tracks level-0 tasks and explicit task-group children, not battle/page titles.
/// save_error_log keeps the final separator plus the preceding two lines,
/// so these headings survive even when scheduler/[Task] messages are omitted.
class LogTaskContext {
  static final _logPrefix = RegExp(
    r'^.*?\|\s*(?:DEBUG|INFO|WARNING|ERROR|CRITICAL)\s*\|\s*',
  );
  static final _equalTitle = RegExp(r'^═{10,}\s*(.*?)\s*═{10,}$');
  static final _groupItem = RegExp(
    r'^TASK GROUP\s+\[\d+/\d+\]:\s*(\w+)$',
    caseSensitive: false,
  );
  static final _groupFailure = RegExp(
    r'^Task group(?:\s+`[^`]+`)?\s*:\s*`(\w+)`\s+raised\b',
    caseSensitive: false,
  );

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
    final message = trimmed.replaceFirst(_logPrefix, '');
    final child = _groupItem.firstMatch(
      _equalTitle.firstMatch(trimmed)?.group(1)?.trim() ?? message,
    );
    final failure = _groupFailure.firstMatch(message);
    if (child != null || failure != null) {
      // Group children use level-1 rules. The failure line also survives when
      // the child's start was omitted from a saved or paginated log.
      task = _canonicalTask((failure ?? child)!.group(1)!);
    }
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
