import 'package:flutter/material.dart';
import 'package:oasx/modules/settings/widgets/setting_item.dart';

class SettingCard extends StatelessWidget {
  final String title;
  final List<SettingItem> items;

  const SettingCard({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final (index, item) in items.indexed) ...[
              if (index > 0) const Divider(height: 16),
              item,
            ],
          ],
        ),
      ),
    );
  }
}
