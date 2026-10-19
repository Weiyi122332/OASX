part of 'log_center_panel.dart';

/// Error report export and task-colored action map.
class LogCenterErrorDetailView extends StatelessWidget {
  const LogCenterErrorDetailView({
    super.key,
    required this.controller,
    required this.detailScrollController,
    required this.detailHorizontalScrollController,
  });
  final ScriptLogBrowserController controller;
  final ScrollController detailScrollController;
  final ScrollController detailHorizontalScrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Obx(() {
      final detail = controller.selectedErrorDetail.value;
      final summary = detail == null
          ? null
          : ErrorLogSummary.parse(
              detail.log.content,
              truncated: detail.log.truncated,
            );
      final exporting = controller.exportingErrorReport.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: I18n.back.tr,
                  onPressed: controller.backToErrorList,
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summary?.task.tr ?? controller.selectedErrorTitle.value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: detail == null
                ? Center(
                    child: controller.errorDetailLoading.value
                        ? const CircularProgressIndicator()
                        : Text(
                            controller.errorMessage.value.isEmpty
                                ? '请选择错误日志'
                                : controller.errorMessage.value,
                          ),
                  )
                : Scrollbar(
                    controller: detailScrollController,
                    thumbVisibility: true,
                    child: ListView(
                      controller: detailScrollController,
                      padding: const EdgeInsets.only(right: 8, bottom: 16),
                      children: [
                        _ErrorDetailSection(
                          borderColor: colors.error.withValues(alpha: .22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: colors.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '错误摘要',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SelectableText(
                                summary!.type,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                controller.formatErrorTimestamp(
                                  detail.timestampMs,
                                  detail.time,
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '配置：${detail.scriptName ?? "归属未确认"}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ErrorDetailSection(
                          borderColor: colors.primary.withValues(alpha: .2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 20,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '导出错误报告',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                title: const Text('任务详细设置'),
                                subtitle: const Text(
                                  '报告中以表格展示最后报错任务的当前设置；无可用设置时留空。',
                                ),
                                value:
                                    controller.includeErrorTaskSettings.value,
                                onChanged: exporting
                                    ? null
                                    : (value) {
                                        controller
                                                .includeErrorTaskSettings
                                                .value =
                                            value ?? false;
                                      },
                              ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 46),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: exporting
                                    ? null
                                    : controller.exportErrorReport,
                                icon: exporting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.file_download_outlined,
                                        size: 20,
                                      ),
                                label: Text(
                                  exporting
                                      ? '正在制作报告…'
                                      : '下载 Markdown 报告（图片和日志）',
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '仅点击下载后制作。截图内嵌，需使用支持 data URI 的 Markdown 阅读器；设置为导出时的保存值，并非历史快照。',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (detail.log.truncated)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '日志超过接口上限（1 MiB），报告与点击图仅包含返回部分。',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.error,
                              ),
                            ),
                          ),
                        ActionPathCard(
                          key: ValueKey(detail.id),
                          data: analyzeErrorLog(detail),
                          colorByTask: true,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      );
    });
  }
}

class _ErrorDetailSection extends StatelessWidget {
  const _ErrorDetailSection({required this.child, required this.borderColor});
  final Widget child;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor),
    ),
    child: child,
  );
}
