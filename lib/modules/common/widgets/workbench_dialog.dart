import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/translation/i18n_content.dart';

/// A scrollable detail or confirmation dialog with a bounded content width.
class WorkbenchDialog extends StatelessWidget {
  const WorkbenchDialog({
    super.key,
    required this.title,
    required this.content,
    this.width = 360,
    this.actions,
  });

  final String title;
  final Widget content;
  final double width;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(title),
    content: SizedBox(width: width, child: content),
    actions:
        actions ??
        [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(I18n.close.tr),
          ),
        ],
  );
}
