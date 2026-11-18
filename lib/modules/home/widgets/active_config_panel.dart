import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/models/config_model.dart';
import 'package:oasx/modules/home/models/home_workbench_layout.dart';
import 'package:oasx/modules/home/widgets/config_state_indicator.dart';
import 'package:oasx/modules/home/widgets/log_center_panel.dart';
import 'package:oasx/modules/home/widgets/statistics_panel.dart';
import 'package:oasx/modules/home/widgets/workbench_tabs.dart';
import 'package:oasx/modules/home/widgets/resource_inventory_panel.dart';
import 'package:oasx/modules/home/widgets/task_catalog_panel.dart';
import 'package:oasx/modules/home/widgets/task_status_panel.dart';
import 'package:oasx/translation/i18n_content.dart';

class ActiveConfigPanel extends StatelessWidget {
  const ActiveConfigPanel({
    super.key,
    required this.controller,
    required this.layoutMode,
    required this.onChangeTab,
    required this.onOpenTask,
    required this.onTogglePower,
    required this.onRenameScript,
    required this.onDeleteScript,
    required this.onSetNextRun,
    required this.onQuickRun,
    required this.onQuickWait,
    required this.onBulkQuickRun,
    required this.onBulkQuickWait,
    this.onExpandRightSidebar,
    this.onBackToScripts,
  });

  final HomeDashboardController controller;
  final HomeWorkbenchLayoutMode layoutMode;
  final Future<void> Function(HomeWorkbenchTab tab) onChangeTab;
  final Future<void> Function(
    String taskName,
    HomeTaskParameterEntrySource source,
  )
  onOpenTask;
  final Future<void> Function(String scriptName, bool enable) onTogglePower;
  final Future<void> Function(String scriptName) onRenameScript;
  final Future<void> Function(String scriptName) onDeleteScript;
  final Future<void> Function(String taskName, String nextRun) onSetNextRun;
  final Future<void> Function(String taskName) onQuickRun;
  final Future<void> Function(String taskName) onQuickWait;
  final Future<void> Function() onBulkQuickRun;
  final Future<void> Function() onBulkQuickWait;
  final VoidCallback? onExpandRightSidebar;
  final VoidCallback? onBackToScripts;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Obx(() {
          final script = controller.activeScriptModel;
          final currentTab = controller.displayedWorkbenchTabFor(layoutMode);
          final tabs = controller.workbenchTabsFor(layoutMode);
          if (script == null) {
            return Center(child: Text(I18n.homeNoScriptSelected.tr));
          }
          final isRunning = script.state.value == ScriptState.running;
          final bulkMode = controller.bulkQuickScheduleMode.value;
          final hasBulkTasks = controller
              .quickSchedulableTaskNamesFor(script)
              .isNotEmpty;
          final isBulkIdle = bulkMode == HomeBulkQuickScheduleMode.none;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 480;
                  final powerLabel = isRunning ? I18n.stop.tr : I18n.run.tr;
                  final powerIcon = isRunning
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded;
                  Future<void> onPower() =>
                      onTogglePower(script.name, !isRunning);
                  return Row(
                    children: [
                      if (onBackToScripts != null)
                        IconButton(
                          tooltip: I18n.scriptList.tr,
                          onPressed: onBackToScripts,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: script.name,
                              child: Text(
                                script.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(height: 2),
                            ConfigStateIndicator(
                              state: controller.scriptStateFor(script),
                            ),
                          ],
                        ),
                      ),
                      if (wide) ...[
                        _BulkQuickScheduleButton(
                          icon: Icons.flash_on_rounded,
                          tooltip: I18n.homeQuickRunAll.tr,
                          loading: bulkMode == HomeBulkQuickScheduleMode.runNow,
                          onPressed: isBulkIdle && hasBulkTasks
                              ? onBulkQuickRun
                              : null,
                        ),
                        _BulkQuickScheduleButton(
                          icon: Icons.schedule_rounded,
                          tooltip: I18n.homeQuickWaitAll.tr,
                          loading:
                              bulkMode == HomeBulkQuickScheduleMode.waitNow,
                          onPressed: isBulkIdle && hasBulkTasks
                              ? onBulkQuickWait
                              : null,
                        ),
                      ] else
                        PopupMenuButton<HomeBulkQuickScheduleMode>(
                          tooltip: I18n.homeMoreActions.tr,
                          enabled: isBulkIdle && hasBulkTasks,
                          icon: isBulkIdle
                              ? const Icon(Icons.more_horiz_rounded)
                              : const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: HomeBulkQuickScheduleMode.runNow,
                              child: Text(I18n.homeQuickRunAll.tr),
                            ),
                            PopupMenuItem(
                              value: HomeBulkQuickScheduleMode.waitNow,
                              child: Text(I18n.homeQuickWaitAll.tr),
                            ),
                          ],
                          onSelected: (mode) =>
                              mode == HomeBulkQuickScheduleMode.runNow
                              ? onBulkQuickRun()
                              : onBulkQuickWait(),
                        ),
                      if (onExpandRightSidebar != null)
                        IconButton(
                          key: const ValueKey<String>(
                            'home-workbench-expand-right-sidebar',
                          ),
                          tooltip: I18n.homeRestoreSidebar.tr,
                          onPressed: onExpandRightSidebar,
                          icon: const Icon(
                            Icons.keyboard_double_arrow_left_rounded,
                          ),
                        ),
                      const SizedBox(width: 4),
                      if (constraints.maxWidth <
                          MediaQuery.textScalerOf(context).scale(260))
                        IconButton.filledTonal(
                          tooltip: powerLabel,
                          onPressed: onPower,
                          icon: Icon(powerIcon),
                        )
                      else
                        FilledButton.tonalIcon(
                          onPressed: onPower,
                          icon: Icon(powerIcon, size: 18),
                          label: Text(powerLabel),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              WorkbenchTabs(
                tabs: tabs,
                selected: currentTab,
                onSelected: onChangeTab,
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildTabContent(script, currentTab)),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTabContent(ScriptModel script, HomeWorkbenchTab currentTab) {
    return switch (currentTab) {
      HomeWorkbenchTab.status => TaskStatusPanel(
        controller: controller,
        scriptModel: script,
        canQuickScheduleTask: (taskName) =>
            controller.canQuickScheduleTask(script, taskName),
        onSetNextRun: onSetNextRun,
        onQuickRun: onQuickRun,
        onQuickWait: onQuickWait,
        onEditTask: (taskName) =>
            onOpenTask(taskName, HomeTaskParameterEntrySource.overview),
      ),
      HomeWorkbenchTab.tasks => TaskCatalogPanel(
        controller: controller,
        scriptModel: script,
        onOpenTask: (taskName) =>
            onOpenTask(taskName, HomeTaskParameterEntrySource.tasks),
        onQuickRun: onQuickRun,
        onQuickWait: onQuickWait,
      ),
      HomeWorkbenchTab.stats => const ScriptStatisticsPanel(),
      HomeWorkbenchTab.logs => LogCenterPanel(scriptName: script.name),
      HomeWorkbenchTab.resources => ResourceInventoryPanel(
        scriptName: script.name,
      ),
    };
  }
}

class _BulkQuickScheduleButton extends StatelessWidget {
  const _BulkQuickScheduleButton({
    required this.icon,
    required this.tooltip,
    required this.loading,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: loading ? null : onPressed,
      icon: loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : Icon(icon),
    );
  }
}
