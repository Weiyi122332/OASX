import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/translation/i18n_content.dart';

/// Both workbench panes use the same labels and controlled selection.
class WorkbenchTabs extends StatelessWidget {
  const WorkbenchTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<HomeWorkbenchTab> tabs;
  final HomeWorkbenchTab selected;
  final ValueChanged<HomeWorkbenchTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final showIcons =
            constraints.maxWidth >=
            tabs.length * MediaQuery.textScalerOf(context).scale(86);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 4,
            runSpacing: 2,
            children: tabs.map((tab) {
              final (label, icon) = switch (tab) {
                HomeWorkbenchTab.status => (
                  I18n.overview,
                  Icons.dashboard_outlined,
                ),
                HomeWorkbenchTab.tasks => (
                  I18n.homeTasksTab,
                  Icons.checklist_rounded,
                ),
                HomeWorkbenchTab.logs => (I18n.log, Icons.notes_rounded),
                HomeWorkbenchTab.stats => (
                  I18n.homeStatsTab,
                  Icons.bar_chart_rounded,
                ),
                HomeWorkbenchTab.resources => (
                  I18n.homeResourcesTab,
                  Icons.inventory_2_outlined,
                ),
              };
              final active = tab == selected;
              final foreground = active
                  ? colors.onPrimary
                  : colors.onSurfaceVariant;
              return ChoiceChip(
                selected: active,
                onSelected: (_) => onSelected(tab),
                label: Text(label.tr),
                avatar: showIcons
                    ? Icon(icon, size: 16, color: foreground)
                    : null,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                selectedColor: colors.primary,
                backgroundColor: Colors.transparent,
                showCheckmark: false,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
