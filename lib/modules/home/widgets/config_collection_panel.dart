import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/common/widgets/workbench_select.dart';
import 'package:oasx/modules/common/models/config_drag_payload.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/models/config_model.dart';
import 'package:oasx/modules/home/widgets/config_collection_tile.dart';
import 'package:oasx/modules/home/widgets/config_state_indicator.dart';
import 'package:oasx/translation/i18n_content.dart';

class ConfigCollectionPanel extends StatefulWidget {
  static const _visibleStateFilters = [
    HomeScriptStateFilter.all,
    HomeScriptStateFilter.running,
    HomeScriptStateFilter.stopped,
    HomeScriptStateFilter.abnormal,
  ];

  const ConfigCollectionPanel({
    super.key,
    required this.controller,
    required this.fillHeight,
    required this.loadingAddScript,
    required this.refreshingScripts,
    required this.onAddScriptTap,
    required this.onRefreshScriptsTap,
    required this.onActivateScript,
    required this.onTogglePower,
    required this.onRenameScript,
    required this.onExportScript,
    required this.onDeleteScript,
  });

  final HomeDashboardController controller;
  final bool fillHeight;
  final bool loadingAddScript;
  final bool refreshingScripts;
  final VoidCallback onAddScriptTap;
  final VoidCallback onRefreshScriptsTap;
  final Future<void> Function(String scriptName) onActivateScript;
  final Future<void> Function(String scriptName, bool enable) onTogglePower;
  final Future<void> Function(String scriptName) onRenameScript;
  final Future<void> Function(String scriptName) onExportScript;
  final Future<void> Function(String scriptName) onDeleteScript;

  @override
  State<ConfigCollectionPanel> createState() => _ConfigCollectionPanelState();
}

class _ConfigCollectionPanelState extends State<ConfigCollectionPanel> {
  static const _autoScrollEdgeExtent = 56.0;
  static const _autoScrollStep = 10.0;

  late final TextEditingController _searchController;
  final ScrollController _listScrollController = ScrollController();
  final GlobalKey _listViewportKey = GlobalKey();
  Timer? _autoScrollTimer;
  double _autoScrollDirection = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.searchQuery.value,
    );
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _searchController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Obx(() {
          final activeDragPayload = widget.controller.activeDragPayload.value;
          if (activeDragPayload == null) {
            _stopAutoScroll();
          }
          final scripts = widget.controller.visibleScripts;
          final allScripts = widget.controller.orderedScripts;
          final counts = {
            for (final state in ConfigCollectionPanel._visibleStateFilters)
              state: state == HomeScriptStateFilter.all
                  ? allScripts.length
                  : widget.controller.countScriptsByState(state),
          };
          final filter = widget.controller.stateFilter.value;
          final linked = widget.controller.isLinkModeEnabled.value;
          final searchValue = widget.controller.searchQuery.value;
          if (_searchController.text != searchValue) {
            _searchController.value = TextEditingValue(
              text: searchValue,
              selection: TextSelection.collapsed(offset: searchValue.length),
            );
          }
          final listView = DragTarget<ConfigDragPayload>(
            onWillAcceptWithDetails: (_) => true,
            onMove: (details) => _handleDragMove(details.offset),
            onLeave: (_) => _stopAutoScroll(),
            builder: (context, _, __) => SizedBox.expand(
              key: _listViewportKey,
              child: ListView.separated(
                controller: _listScrollController,
                itemCount: scripts.length,
                padding: EdgeInsets.zero,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (context, index) =>
                    _buildDropTargetTile(context, scripts[index]),
              ),
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, linked),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: widget.controller.setSearchQuery,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: I18n.homeScriptSearchHint.tr,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: searchValue.isEmpty
                      ? null
                      : IconButton(
                          tooltip: I18n.clear.tr,
                          onPressed: () => widget.controller.setSearchQuery(''),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              _buildFilters(filter, counts),
              const SizedBox(height: 8),
              ExpandedOrSizedBox(
                fillHeight: widget.fillHeight,
                child: scripts.isNotEmpty
                    ? listView
                    : Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                allScripts.isEmpty
                                    ? Icons.folder_open_rounded
                                    : Icons.search_off_rounded,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                allScripts.isEmpty
                                    ? I18n.homeEmptyScriptHint.tr
                                    : I18n.homeNoMatchingConfigs.tr,
                                textAlign: TextAlign.center,
                              ),
                              if (allScripts.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    widget.controller.setSearchQuery('');
                                    widget.controller.setStateFilterValue(
                                      HomeScriptStateFilter.all,
                                    );
                                  },
                                  child: Text(I18n.homeResetFilters.tr),
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Wraps one config tile in the drop target used by drag-copy flows.
  Widget _buildDropTargetTile(BuildContext context, ScriptModel script) {
    return DragTarget<ConfigDragPayload>(
      onWillAcceptWithDetails: (details) {
        return _canAcceptPayload(script.name, details.data);
      },
      onMove: (details) => _handleDragMove(details.offset),
      onLeave: (_) => _stopAutoScroll(),
      onAcceptWithDetails: (details) async {
        _stopAutoScroll();
        widget.controller.clearConfigDrag();
        await widget.controller.acceptConfigDrag(
          payload: details.data,
          destinationConfig: script.name,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final candidate = candidateData.isNotEmpty ? candidateData.first : null;
        final isHighlighted = _canAcceptPayload(script.name, candidate);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isHighlighted
                ? Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.28)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isHighlighted
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
            ),
          ),
          child: ConfigCollectionTile(
            controller: widget.controller,
            script: script,
            onTap: () => widget.onActivateScript(script.name),
            onTogglePower: () => widget.onTogglePower(
              script.name,
              script.state.value != ScriptState.running,
            ),
            onRename: () => widget.onRenameScript(script.name),
            onExport: () => widget.onExportScript(script.name),
            onDelete: () => widget.onDeleteScript(script.name),
          ),
        );
      },
    );
  }

  /// Returns whether the dragged payload may be dropped on the config row.
  bool _canAcceptPayload(String destinationConfig, ConfigDragPayload? payload) {
    return payload != null &&
        payload.canDropOn(destinationConfig) &&
        !widget.controller.isDragCopyPendingFor(destinationConfig);
  }

  /// Starts or stops list auto-scroll based on the current drag location.
  void _handleDragMove(Offset globalOffset) {
    final renderObject = _listViewportKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      _stopAutoScroll();
      return;
    }
    final localOffset = renderObject.globalToLocal(globalOffset);
    final viewportHeight = renderObject.size.height;
    if (localOffset.dy <= _autoScrollEdgeExtent) {
      _startAutoScroll(-1);
      return;
    }
    if (localOffset.dy >= viewportHeight - _autoScrollEdgeExtent) {
      _startAutoScroll(1);
      return;
    }
    _stopAutoScroll();
  }

  /// Creates one periodic scroll loop in the given direction.
  void _startAutoScroll(double direction) {
    if (_autoScrollTimer != null && _autoScrollDirection == direction) {
      return;
    }
    _stopAutoScroll();
    _autoScrollDirection = direction;
    _autoScrollTimer = Timer.periodic(
      const Duration(milliseconds: 24),
      (_) => _tickAutoScroll(),
    );
  }

  /// Advances the list while drag hover stays inside one edge zone.
  void _tickAutoScroll() {
    if (!_listScrollController.hasClients) {
      _stopAutoScroll();
      return;
    }
    final position = _listScrollController.position;
    final currentOffset = position.pixels;
    final nextOffset = (currentOffset + _autoScrollDirection * _autoScrollStep)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((nextOffset - currentOffset).abs() < 0.5) {
      _stopAutoScroll();
      return;
    }
    _listScrollController.jumpTo(nextOffset);
  }

  /// Cancels any running auto-scroll loop.
  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollDirection = 0;
  }

  Widget _buildHeader(BuildContext context, bool linked) {
    final title = Text(
      I18n.scriptList.tr,
      style: Theme.of(context).textTheme.titleLarge,
    );
    final actions = Wrap(
      children: [
        IconButton(
          tooltip: I18n.homeConnectionRetryAction.tr,
          onPressed: widget.refreshingScripts
              ? null
              : widget.onRefreshScriptsTap,
          icon: widget.refreshingScripts
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: linked ? I18n.closeTheLinker.tr : I18n.turnOnTheLinker.tr,
          isSelected: linked,
          onPressed: widget.controller.toggleLinkMode,
          style: linked
              ? IconButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                )
              : null,
          icon: const Icon(Icons.link_rounded),
        ),
        IconButton.filled(
          tooltip: I18n.configAdd.tr,
          onPressed: widget.loadingAddScript ? null : widget.onAddScriptTap,
          icon: widget.loadingAddScript
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_rounded),
        ),
      ],
    );
    return OverflowBar(
      alignment: MainAxisAlignment.spaceBetween,
      overflowAlignment: OverflowBarAlignment.start,
      spacing: 8,
      children: [title, actions],
    );
  }

  Widget _buildFilters(
    HomeScriptStateFilter filter,
    Map<HomeScriptStateFilter, int> counts,
  ) {
    const options = ConfigCollectionPanel._visibleStateFilters;
    String label(HomeScriptStateFilter state) =>
        '${state.label} ${counts[state] ?? 0}';
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <
            MediaQuery.textScalerOf(context).scale(260)) {
          return WorkbenchSelect<HomeScriptStateFilter>(
            options: options,
            value: filter,
            semanticLabel: I18n.homeFilterByState.tr,
            optionLabel: label,
            leadingIcon: Icons.filter_list_rounded,
            onChanged: widget.controller.setStateFilterValue,
          );
        }
        return Wrap(
          spacing: 4,
          runSpacing: 2,
          children: [
            for (final state in options)
              ChoiceChip(
                selected: state == filter,
                showCheckmark: false,
                label: Text(label(state)),
                labelStyle: Theme.of(context).textTheme.labelMedium,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
                onSelected: (_) => widget.controller.setStateFilterValue(state),
              ),
          ],
        );
      },
    );
  }
}

class ExpandedOrSizedBox extends StatelessWidget {
  const ExpandedOrSizedBox({
    super.key,
    required this.fillHeight,
    required this.child,
  });

  final bool fillHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (fillHeight) {
      return Expanded(child: child);
    }
    return SizedBox(height: 320, child: child);
  }
}
