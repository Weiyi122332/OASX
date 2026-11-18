import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/models/home_workbench_layout.dart';
import 'package:oasx/modules/home/widgets/log_center_panel.dart';
import 'package:oasx/modules/home/widgets/statistics_panel.dart';
import 'package:oasx/modules/home/widgets/workbench_tabs.dart';
import 'package:oasx/modules/home/widgets/resource_inventory_panel.dart';

/// Hosts the desktop right sidebar for statistics and logs.
class WorkbenchSidebarPanel extends StatelessWidget {
  /// Creates the right workbench sidebar.
  const WorkbenchSidebarPanel({
    super.key,
    required this.controller,
    required this.scriptName,
  });

  /// Dashboard controller that owns sidebar tab state.
  final HomeDashboardController controller;

  /// Active script rendered by the sidebar.
  final String scriptName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Obx(() {
          final tabs = controller.workbenchSidebarTabsFor(
            HomeWorkbenchLayoutMode.threePane,
          );
          final currentTab = controller.displayedWorkbenchSidebarTabFor(
            HomeWorkbenchLayoutMode.threePane,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WorkbenchTabs(
                tabs: tabs,
                selected: currentTab,
                onSelected: controller.setActiveWorkbenchSidebarTabValue,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: switch (currentTab) {
                  HomeWorkbenchTab.stats => const ScriptStatisticsPanel(),
                  HomeWorkbenchTab.logs => LogCenterPanel(
                    scriptName: scriptName,
                  ),
                  HomeWorkbenchTab.resources => ResourceInventoryPanel(
                    scriptName: scriptName,
                  ),
                  _ => const SizedBox.shrink(),
                },
              ),
            ],
          );
        }),
      ),
    );
  }
}
