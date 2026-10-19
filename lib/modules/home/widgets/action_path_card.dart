import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/models/script_analysis_models.dart';
import 'package:oasx/translation/i18n_content.dart';

Color taskPathColor(String task) {
  var hash = 0;
  for (final code in task.codeUnits) {
    hash = (hash * 31 + code) % 360;
  }
  return HSLColor.fromAHSL(1, hash.toDouble(), .65, .48).toColor();
}

class ActionPathCard extends StatefulWidget {
  const ActionPathCard({
    super.key,
    required this.data,
    this.colorByTask = false,
  });
  final ScriptAnalysisSnapshot data;
  final bool colorByTask;
  @override
  State<ActionPathCard> createState() => _ActionPathCardState();
}

class _ActionPathCardState extends State<ActionPathCard> {
  bool clicks = true, swipes = true, path = true;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .65)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              I18n.homeAnalysisPathTitle.tr,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilterChip(
                  label: Text(I18n.homeAnalysisShowClicks.tr),
                  selected: clicks,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: .65),
                  ),
                  onSelected: (v) => setState(() => clicks = v),
                ),
                FilterChip(
                  label: Text(I18n.homeAnalysisShowSwipes.tr),
                  selected: swipes,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: .65),
                  ),
                  onSelected: (v) => setState(() => swipes = v),
                ),
                FilterChip(
                  label: Text(I18n.homeAnalysisShowPath.tr),
                  selected: path,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: .65),
                  ),
                  onSelected: (v) => setState(() => path = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.data.events.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('此错误日志中没有可识别的点击或滑动记录'),
              )
            else
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: .65),
                  ),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    child: CustomPaint(
                      painter: _ActionPathPainter(
                        widget.data.events,
                        clicks,
                        swipes,
                        path,
                        Theme.of(context).colorScheme,
                        widget.colorByTask,
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.colorByTask) const SizedBox(height: 12),
            if (widget.colorByTask)
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (final task
                      in widget.data.events.map((e) => e.task).toSet())
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: taskPathColor(task).withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 7,
                            color: taskPathColor(task),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              task.tr,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionPathPainter extends CustomPainter {
  _ActionPathPainter(
    this.events,
    this.showClicks,
    this.showSwipes,
    this.showPath,
    this.colors,
    this.colorByTask,
  );
  final List<ScriptActionEvent> events;
  final bool showClicks;
  final bool showSwipes;
  final bool showPath;
  final ColorScheme colors;
  final bool colorByTask;

  Offset _point(double x, double y, Size size) =>
      Offset(x / 1280 * size.width, y / 720 * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    final clicks = events
        .where((e) => e.kind == ScriptActionKind.click)
        .toList();
    if (showPath && clicks.length > 1) {
      final path = Path()
        ..moveTo(
          _point(clicks.first.startX, clicks.first.startY, size).dx,
          _point(clicks.first.startX, clicks.first.startY, size).dy,
        );
      for (var i = 1; i < clicks.length; i++) {
        final event = clicks[i];
        final point = _point(event.startX, event.startY, size);
        if (colorByTask && clicks[i - 1].task != event.task) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colors.primary.withValues(alpha: colorByTask ? .24 : .32)
          ..strokeWidth = colorByTask ? .7 : 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }
    if (showSwipes) {
      for (final event in events.where(
        (e) => e.kind == ScriptActionKind.swipe,
      )) {
        canvas.drawLine(
          _point(event.startX, event.startY, size),
          _point(event.endX, event.endY, size),
          Paint()
            ..color = colors.tertiary.withValues(alpha: .45)
            ..strokeWidth = colorByTask ? 1 : 2
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    if (showClicks) {
      for (final event in clicks) {
        canvas.drawCircle(
          _point(event.startX, event.startY, size),
          2,
          Paint()
            ..color =
                (colorByTask
                        ? taskPathColor(event.task)
                        : (event.isRandomClick ? colors.error : colors.primary))
                    .withValues(alpha: event.isRandomClick ? .6 : .5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ActionPathPainter oldDelegate) => true;
}
