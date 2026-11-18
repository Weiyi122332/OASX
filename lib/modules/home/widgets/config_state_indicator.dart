import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/translation/i18n_content.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';

extension ConfigStateLabel on HomeScriptStateFilter {
  String get label => switch (this) {
    HomeScriptStateFilter.all => I18n.homeFilterAll.tr,
    HomeScriptStateFilter.running => I18n.trayRunningConfigs.tr,
    HomeScriptStateFilter.stopped => I18n.trayStoppedConfigs.tr,
    HomeScriptStateFilter.abnormal => I18n.homeScriptAbnormal.tr,
    HomeScriptStateFilter.offline => I18n.homeScriptOffline.tr,
  };
}

class ConfigStateIndicator extends StatelessWidget {
  const ConfigStateIndicator({super.key, required this.state, this.size = 12});

  final HomeScriptStateFilter state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _paletteFor(state, context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(palette.icon, size: size, color: palette.color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            state.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  _StatePalette _paletteFor(HomeScriptStateFilter value, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (value) {
      HomeScriptStateFilter.running => const _StatePalette(
        color: Colors.green,
        icon: Icons.circle_rounded,
      ),
      HomeScriptStateFilter.abnormal => const _StatePalette(
        color: Colors.orange,
        icon: Icons.circle_rounded,
      ),
      HomeScriptStateFilter.stopped => const _StatePalette(
        color: Colors.grey,
        icon: Icons.donut_large,
      ),
      HomeScriptStateFilter.offline => const _StatePalette(
        color: Colors.blue,
        icon: Icons.browser_updated_rounded,
      ),
      HomeScriptStateFilter.all => _StatePalette(
        color: scheme.outline,
        icon: Icons.circle,
      ),
    };
  }
}

class _StatePalette {
  const _StatePalette({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}
