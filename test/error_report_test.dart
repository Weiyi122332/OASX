import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/modules/log/log_browser_models.dart';
import 'package:oasx/modules/log/models/error_report.dart';

ScriptErrorLogDetail detail(String text, {bool truncated = false}) =>
    ScriptErrorLogDetail(
      id: 'demo_1',
      directory: 'demo_1',
      scriptName: 'demo',
      timestampMs: 0,
      time: '2026-10-16 00:00:01',
      legacy: false,
      log: ScriptErrorLogText(
        fileName: 'log.txt',
        content: text,
        size: text.length,
        limitBytes: 1048576,
        truncated: truncated,
      ),
      images: const [],
    );

void main() {
  test(
    'settings stay attached to the last error, not a later task heading',
    () {
      final summary = ErrorLogSummary.parse(
        '[Task] Chess (Enable)\nValueError: failed\n'
        '[Task] Restart (Enable)\n',
      );
      expect(summary.task, 'Chess');
    },
  );
  test('task settings are readable grouped tables, not a JSON attachment', () {
    final report = buildErrorMarkdown(
      detail('[Task] Chess (Enable)\nValueError: failed'),
      [],
      includeTaskSettings: true,
      taskSettings: const ErrorTaskSettings(
        {
          'chess_config': {
            'lineup_bond': '冥火',
            'rank_protection': true,
            'run_count': 3,
            'optional': null,
            'choices': ['甲', '乙'],
            'limit_time': {'hour': 0, 'minute': 30},
          },
        },
        schema: {
          'chess_config': [
            {'name': 'lineup_bond', 'title': '选择阵容'},
            {'name': 'rank_protection', 'title': '保段位'},
            {'name': 'run_count', 'title': '执行次数'},
          ],
        },
      ),
      translate: (text) => text == 'chess_config' ? '下棋设置' : text,
    );
    expect(report, contains('### 下棋设置'));
    expect(report, contains('| 选择阵容 | 冥火 |'));
    expect(report, contains('| 保段位 | 开启 |'));
    expect(report, contains('| 执行次数 | 3 |'));
    expect(report, contains('甲、乙'));
    expect(report, contains('minute：30'));
    expect(report, contains('不是报错时的历史快照'));
    expect(report, isNot(contains('```json')));
  });
  test(
    'task settings are opt-in and absent settings leave no invented rows',
    () {
      final log = detail('[Task] Chess (Enable)\nValueError: test');
      expect(buildErrorMarkdown(log, []), isNot(contains('## 任务详细设置')));
      final report = buildErrorMarkdown(log, [], includeTaskSettings: true);
      expect(report, contains('## 任务详细设置'));
      expect(report, isNot(contains('| 设置项 |')));
      expect(report, contains('## 截图'));
      expect(report, contains('## 日志'));
    },
  );
  test('setting text cannot inject Markdown tables, headings or images', () {
    final report = buildErrorMarkdown(
      detail('ValueError: test'),
      [],
      includeTaskSettings: true,
      taskSettings: const ErrorTaskSettings({
        'group': {'name': 'a|b\n![bad](https://invalid) <script> ` **'},
      }),
    );
    expect(report, contains('a&#124;b<br>'));
    expect(report, contains('&lt;script&gt;'));
    expect(report, isNot(contains('![bad]')));
  });
  test(
    'settings loader uses error config and task, and failure is optional',
    () async {
      var calls = 0;
      final settings = await loadErrorTaskSettings(
        detail(
          '[Task] Chess (Enable)\nValueError: test\n[Task] Restart (Enable)',
        ),
        load: (config, task) async {
          calls++;
          expect(config, 'demo');
          expect(task, 'Chess');
          return const ErrorTaskSettings({
            'chess_config': {'run_count': 1},
          });
        },
      );
      expect(calls, 1);
      expect(settings.values, isNotEmpty);
      final unavailable = await loadErrorTaskSettings(
        detail('[Task] Chess (Enable)\nValueError: test'),
        load: (_, _) async => throw StateError('missing config'),
      );
      expect(unavailable.values, isEmpty);
    },
  );
  test(
    'unknown or truncated errors never fetch another task configuration',
    () async {
      for (final log in [
        detail('ValueError: test'),
        detail('[Task] Chess (Enable)', truncated: true),
      ]) {
        final settings = await loadErrorTaskSettings(
          log,
          load: (_, _) async {
            fail('Unknown task must not fetch settings');
          },
        );
        expect(settings.values, isEmpty);
      }
      final unknown = detail('[Task] Chess (Enable)').withScriptName(null);
      expect(
        (await loadErrorTaskSettings(
          unknown,
          load: (_, _) async {
            fail('Unknown config must not use selected UI config');
          },
        )).values,
        isEmpty,
      );
    },
  );
  test('saved error task headings survive scheduler line truncation', () {
    final text =
        '${'═' * 40}\n${'─' * 15} REALMRAID ${'─' * 15}\n${'═' * 40}\n'
        '2026-10-16 00:00:00.000 | INFO | Click (10, 20) @ OK\n'
        '${'─' * 15} GENERAL BATTLE START ${'─' * 15}\n'
        '2026-10-16 00:00:01.000 | INFO | Click (20, 30) @ OK\n'
        'GameStuckError: stuck';
    expect(ErrorLogSummary.parse(text).task, 'RealmRaid');
    expect(analyzeErrorLog(detail(text)).events.map((e) => e.task), [
      'RealmRaid',
      'RealmRaid',
    ]);
    expect(buildErrorMarkdown(detail(text), []), contains('任务：RealmRaid'));
  });
  test('last level-zero task heading wins, including custom task names', () {
    final text =
        '${'═' * 40}\n${'─' * 15} REALMRAID ${'─' * 15}\n${'═' * 40}\n'
        '${'═' * 40}\n${'─' * 15} CUSTOMTASK ${'─' * 15}\n${'═' * 40}\n';
    expect(ErrorLogSummary.parse(text).task, 'CUSTOMTASK');
  });
  test('traceback is a fallback when the heading itself is missing', () {
    expect(
      ErrorLogSummary.parse(
        '  File "C:\\oas\\tasks\\RealmRaid\\script_task.py", line 20',
      ).task,
      'RealmRaid',
    );
    expect(
      ErrorLogSummary.parse(
        '  File "/oas/tasks/AreaBoss/script_task.py", line 20',
      ).task,
      'AreaBoss',
    );
  });
  test('subheadings alone do not invent task names', () {
    expect(
      ErrorLogSummary.parse(
        '${'─' * 15} GENERAL BATTLE START ${'─' * 15}',
      ).task,
      '未知任务',
    );
  });
  test('traceback fallback also labels preceding clicks', () {
    final snapshot = analyzeErrorLog(
      detail(
        '2026-10-16 00:00:00.000 | INFO | Click (10, 20) @ OK\n'
        '  File "/oas/tasks/AreaBoss/script_task.py", line 20\nValueError: test',
      ),
    );
    expect(snapshot.events.single.task, 'AreaBoss');
  });
  test('last scheduled task and exception type win', () {
    final summary = ErrorLogSummary.parse(
      '[Task] First (Enable)\n'
      '2026-10-16 00:00:00.000 | INFO | Scheduler: Start task `Last`\n'
      'ValueError: first\nmodule.errors.ScriptError: second',
    );
    expect(summary.task, 'Last');
    expect(summary.type, 'ScriptError');
  });
  test('missing metadata is explicit', () {
    final summary = ErrorLogSummary.parse('unstructured text');
    expect(summary.task, '未知任务');
    expect(summary.type, '未知错误');
  });
  test('truncated logs must not claim to identify the last failing task', () {
    final summary = ErrorLogSummary.parse(
      '[Task] First (Enable)',
      truncated: true,
    );
    expect(summary.task, contains('无法确认最后任务'));
  });
  test('error path spans midnight and retains task identity', () {
    final snapshot = analyzeErrorLog(
      detail(
        '2026-10-15 23:59:59.000 | INFO | Scheduler: Start task `First`\n'
        '2026-10-15 23:59:59.001 | INFO | Click (10, 20) @ OK\n'
        '2026-10-16 00:00:00.000 | INFO | Click (20, 30) @ OK\n'
        '2026-10-16 00:00:00.001 | INFO | Scheduler: Start task `Second`\n'
        '2026-10-16 00:00:00.002 | INFO | Click (30, 40) @ OK',
      ),
    );
    expect(snapshot.clickCount, 3);
    expect(snapshot.events.map((e) => e.task), ['First', 'First', 'Second']);
  });
  test('Markdown embeds bytes, preserves logs and marks truncation', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final report = buildErrorMarkdown(
      detail('log\n```\nend', truncated: true),
      [ScriptErrorImageBytes(fileName: 'image.png', bytes: bytes)],
    );
    expect(report, contains('data:image/png;base64,${base64Encode(bytes)}'));
    expect(report, contains('````text\nlog\n```\nend\n````'));
    expect(report, contains('不是完整日志'));
  });
}
