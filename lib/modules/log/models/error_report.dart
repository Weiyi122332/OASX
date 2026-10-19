import 'dart:convert';

import 'package:oasx/modules/home/models/script_analysis_models.dart';
import 'package:oasx/modules/log/log_browser_models.dart';
import 'log_task_context.dart';

/// Metadata is derived from existing logs, so older backends remain compatible.
class ErrorLogSummary {
  const ErrorLogSummary(this.task, this.type);
  final String task;
  final String type;

  factory ErrorLogSummary.parse(String text, {bool truncated = false}) {
    final tasks = LogTaskContext();
    var type = '未知错误';
    String? errorTask;
    var sawError = false;
    final exception = RegExp(
      r'^\s*(?:[\w.]+\.)?([A-Za-z_]\w*(?:Error|Exception)|KeyboardInterrupt|SystemExit):',
    );
    for (final line in const LineSplitter().convert(text)) {
      tasks.consume(line);
      final error = exception.firstMatch(line);
      if (error != null) {
        type = error.group(1)!;
        errorTask = tasks.task ?? tasks.fallbackTask;
        sawError = true;
      } else {
        final level = RegExp(
          r'\|\s*(ERROR|CRITICAL)\s*\|\s*(.+)',
        ).firstMatch(line);
        if (level != null) {
          if (type == '未知错误') type = level.group(2)!.trim();
          errorTask = tasks.task ?? tasks.fallbackTask;
          sawError = true;
        }
      }
    }
    return ErrorLogSummary(
      truncated
          ? '日志已截断，无法确认最后任务'
          : ((sawError ? errorTask : tasks.task ?? tasks.fallbackTask) ??
                '未知任务'),
      truncated ? '已读取部分：$type' : type,
    );
  }
}

/// Redacted values and optional argument labels, fetched only when exporting.
class ErrorTaskSettings {
  const ErrorTaskSettings(this.values, {this.schema = const {}});
  final Map<String, dynamic> values;
  final Map<String, dynamic> schema;
}

Future<ErrorTaskSettings> loadErrorTaskSettings(
  ScriptErrorLogDetail detail, {
  required Future<ErrorTaskSettings> Function(String config, String task) load,
}) async {
  final summary = ErrorLogSummary.parse(
    detail.log.content,
    truncated: detail.log.truncated,
  );
  final config = detail.scriptName?.trim() ?? '';
  if (config.isEmpty || detail.log.truncated || summary.task == '未知任务') {
    return const ErrorTaskSettings({});
  }
  try {
    return await load(config, summary.task);
  } catch (_) {
    // Missing tasks, deleted configs and older backends leave this section empty.
    return const ErrorTaskSettings({});
  }
}

ScriptAnalysisSnapshot analyzeErrorLog(ScriptErrorLogDetail detail) {
  final context = LogTaskContext();
  var date = detail.time.length >= 10
      ? detail.time.substring(0, 10)
      : DateTime.fromMillisecondsSinceEpoch(
          detail.timestampMs,
        ).toIso8601String().substring(0, 10);
  final lines = <ScriptLogLine>[];
  for (final text in const LineSplitter().convert(detail.log.content)) {
    context.consume(text);
    date = RegExp(r'^(\d{4}-\d{2}-\d{2}) ').firstMatch(text)?.group(1) ?? date;
    lines.add(
      ScriptLogLine(
        fileName: '${date}_error.txt',
        lineNo: lines.length + 1,
        offset: 0,
        byteLength: text.length,
        text: text,
        lineTruncated: false,
      ),
    );
  }
  final dates = lines.map((line) => line.fileName.substring(0, 10)).toSet();
  final events =
      dates
          .expand(
            (day) => parseScriptAnalysis(
              lines,
              day,
              fallbackTask: context.fallbackTask,
            ).events,
          )
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
  return ScriptAnalysisSnapshot(events);
}

/// Called only by the explicit export action. Images travel inside the .md file.
String buildErrorMarkdown(
  ScriptErrorLogDetail detail,
  List<ScriptErrorImageBytes> images, {
  bool includeTaskSettings = false,
  ErrorTaskSettings taskSettings = const ErrorTaskSettings({}),
  String Function(String)? translate,
}) {
  final summary = ErrorLogSummary.parse(
    detail.log.content,
    truncated: detail.log.truncated,
  );
  final output = StringBuffer('# OASX 错误报告\n\n');
  output.writeln(
    '- 配置：${detail.scriptName ?? "归属未确认"}\n- 任务：${summary.task}\n- 时间：${detail.time}\n- 错误类型：${summary.type}\n',
  );
  if (detail.log.truncated) output.writeln('> 注意：后端返回的日志已截断，以下不是完整日志。\n');
  if (includeTaskSettings) {
    output.writeln('## 任务详细设置\n');
    output.writeln('> 以下为导出时保存的任务设置（已脱敏），不是报错时的历史快照。\n');
    String label(String value) => translate?.call(value) ?? value;
    for (final group in taskSettings.values.entries) {
      if (group.value is! Map || (group.value as Map).isEmpty) continue;
      output.writeln('### ${_tableText(label(group.key))}\n');
      output.writeln('| 设置项 | 当前值 |\n| :--- | :--- |');
      final schema = taskSettings.schema[group.key];
      for (final entry in (group.value as Map).entries) {
        var title = entry.key.toString();
        if (schema is List) {
          for (final argument in schema.whereType<Map>()) {
            if (argument['name'] == entry.key) {
              title = argument['title']?.toString() ?? title;
              break;
            }
          }
        }
        output.writeln(
          '| ${_tableText(label(title))} | ${_tableText(_settingValue(entry.value, label))} |',
        );
      }
      output.writeln();
    }
  }
  output.writeln('## 截图\n\n图片内嵌于本文件；请使用支持 data URI 的 Markdown 阅读器。\n');
  for (var i = 0; i < images.length; i++) {
    output.writeln(
      '![错误截图 ${i + 1}](data:image/png;base64,${base64Encode(images[i].bytes)})\n',
    );
  }
  // Pick a fence longer than any fence in untrusted log text.
  var fence = '```';
  while (detail.log.content.contains(fence)) {
    fence += '`';
  }
  output.writeln('## 日志\n\n${fence}text\n${detail.log.content}\n$fence');
  return output.toString();
}

String _tableText(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('\\', '&#92;')
    .replaceAll('|', '&#124;')
    .replaceAll('`', '&#96;')
    .replaceAll('*', '&#42;')
    .replaceAll('_', '&#95;')
    .replaceAll('[', '&#91;')
    .replaceAll(']', '&#93;')
    .replaceAll('\r\n', '\n')
    .replaceAll('\n', '<br>');

String _settingValue(dynamic value, String Function(String) label) {
  if (value == null) return '';
  if (value is bool) return value ? '开启' : '关闭';
  if (value is List) return value.map((v) => _settingValue(v, label)).join('、');
  if (value is Map) {
    return value.entries
        .map(
          (e) => '${label(e.key.toString())}：${_settingValue(e.value, label)}',
        )
        .join('\n');
  }
  return label(value.toString());
}
