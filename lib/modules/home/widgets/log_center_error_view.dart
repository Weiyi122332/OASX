part of 'log_center_panel.dart';

/// Error log list and detail view.
class LogCenterErrorView extends StatelessWidget {
  /// Creates the error log view.
  const LogCenterErrorView({
    super.key,
    required this.controller,
    required this.listScrollController,
    required this.detailScrollController,
    required this.detailHorizontalScrollController,
  });

  /// Log browser controller.
  final ScriptLogBrowserController controller;

  /// Scroll controller for the error list.
  final ScrollController listScrollController;

  /// Scroll controller for the error detail.
  final ScrollController detailScrollController;

  /// Horizontal scroll controller for non-wrapped error detail text.
  final ScrollController detailHorizontalScrollController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.errorListLoading.value && controller.errorItems.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.errorMessage.value.isNotEmpty &&
          controller.errorItems.isEmpty) {
        return Center(child: Text(controller.errorMessage.value));
      }
      if (controller.errorItems.isEmpty) {
        return Center(child: Text(I18n.homeLogNoErrors.tr));
      }
      return controller.errorDetailVisible.value
          ? _buildDetail(context)
          : _buildList(context);
    });
  }

  Widget _buildList(BuildContext context) {
    final known = controller.errorItems.where(
      (item) => item.scriptName != null,
    );
    final unknown = controller.errorItems
        .where((item) => item.scriptName == null)
        .toList();
    final entries = <ScriptErrorLogItem?>[
      ...known,
      if (unknown.isNotEmpty) null,
      ...unknown,
    ];
    return Column(
      children: [
        if (controller.errorMessage.value.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              controller.errorMessage.value,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: Scrollbar(
            controller: listScrollController,
            interactive: true,
            thumbVisibility: true,
            child: ListView.separated(
              controller: listScrollController,
              itemCount: entries.length,
              separatorBuilder: (context, index) {
                return const SizedBox(height: 8);
              },
              itemBuilder: (context, index) {
                final item = entries[index];
                if (item == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('归属未确认的旧日志（不计入当前配置）'),
                  );
                }
                return FutureBuilder<ErrorLogSummary>(
                  future: controller.errorSummary(item),
                  builder: (context, snapshot) {
                    final summary = snapshot.data;
                    return Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha: .2),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.error.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.error_outline_rounded,
                            color: Theme.of(context).colorScheme.error,
                            size: 22,
                          ),
                        ),
                        title: Text(summary?.task.tr ?? '正在读取任务…'),
                        subtitle: Text(
                          '${_formatErrorTime(item)}\n配置：${item.scriptName ?? "未确认"}\n${summary?.type ?? "正在识别错误类型…"}',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                        ),
                        onTap: () => controller.selectError(item.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        if (controller.errorHasMore.value) _buildLoadMore(context),
      ],
    );
  }

  Widget _buildLoadMore(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () => controller.loadErrorList(),
        child: Text(I18n.homeLogLoadOlder.tr),
      ),
    );
  }

  Widget _buildDetail(BuildContext context) {
    return LogCenterErrorDetailView(
      controller: controller,
      detailScrollController: detailScrollController,
      detailHorizontalScrollController: detailHorizontalScrollController,
    );
  }

  String _formatErrorTime(ScriptErrorLogItem item) {
    return controller.formatErrorTimestamp(item.timestampMs, item.time);
  }
}
