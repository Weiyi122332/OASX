import 'package:flutter/material.dart';

class SettingItem extends StatelessWidget {
  final Widget left;
  final Widget right;
  final VoidCallback? onTap;

  const SettingItem({
    super.key,
    required this.left,
    required this.right,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = constraints.maxWidth < 480
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  left,
                  const SizedBox(height: 4),
                  Align(alignment: Alignment.centerRight, child: right),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(child: left),
                  const SizedBox(width: 8),
                  right,
                ],
              );
        final padded = Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        );
        return onTap == null ? padded : InkWell(onTap: onTap, child: padded);
      },
    );
  }
}
