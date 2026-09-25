part of args;

/// 任务组的任务列表：一行一个任务，可以「新增任务」加进来、拖动改顺序、点 ✕ 删掉。
///
/// 服务端把这个字段标成 `task_list`（见 OAS 的 tasks/TaskGroup/config.py），
/// 和普通的多选下拉框（multi_enum）不同：这里的顺序就是任务组跑的顺序，
/// 所以要能拖。
class TaskListEditor extends StatelessWidget {
  const TaskListEditor({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
    this.maxCount,
  });

  final List<String> value;
  final List<String> options;
  final ValueChanged<List<String>> onChanged;
  final String? errorText;
  final bool enabled;
  final int? maxCount;

  static const double _menuMaxHeight = 288;

  bool get _isFull => maxCount != null && value.length >= maxCount!;

  /// 还没加进来的任务（已经加过的不再出现在「新增任务」里）。
  List<String> get _remaining {
    final selected = value.toSet();
    return options
        .where((option) => !selected.contains(option))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        value.isEmpty ? _buildEmpty(context) : _buildList(context),
        const SizedBox(height: 6),
        _buildFooter(context),
        if (value.length > 1)
          Text(
            I18n.argsTaskListReorder.tr,
            style: Theme.of(context).textTheme.bodySmall,
          ).padding(top: 4),
        if (errorText != null && errorText!.isNotEmpty)
          Text(
            errorText!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ).padding(top: 4),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        I18n.argsTaskListEmpty.tr,
        style: Theme.of(context).textTheme.bodySmall,
      ).paddingSymmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildList(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      padding: EdgeInsets.zero,
      itemCount: value.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) => _buildRow(context, index),
    );
  }

  Widget _buildRow(BuildContext context, int index) {
    final task = value[index];
    return Container(
      key: ValueKey<String>('task-list-$task'),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Tooltip(
            message: I18n.argsTaskListReorder.tr,
            child: enabled
                ? ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_indicator_outlined)
                        .paddingSymmetric(horizontal: 6, vertical: 10),
                  )
                : const Icon(Icons.drag_indicator_outlined)
                    .paddingSymmetric(horizontal: 6, vertical: 10),
          ),
          Expanded(
            child: Text(
              '${index + 1}. ${task.tr}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ).paddingSymmetric(horizontal: 4),
          ),
          IconButton(
            tooltip: I18n.argsTaskListRemove.tr,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: enabled ? () => _onRemove(index) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final canAdd = enabled && !_isFull && _remaining.isNotEmpty;
    final counter =
        maxCount == null ? '${value.length}' : '${value.length}/$maxCount';
    return Row(
      children: [
        MenuAnchor(
          menuChildren: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _menuMaxHeight),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _remaining
                        .map(
                          (option) => MenuItemButton(
                            onPressed: () => _onAdd(option),
                            child: Text(
                              option.tr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
            ),
          ],
          builder: (context, controller, child) {
            return OutlinedButton.icon(
              onPressed: canAdd
                  ? () => controller.isOpen
                      ? controller.close()
                      : controller.open()
                  : null,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(I18n.argsTaskListAdd.tr),
            );
          },
        ),
        const SizedBox(width: 8),
        Text(
          counter,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _onAdd(String task) {
    if (_isFull || value.contains(task)) {
      return;
    }
    onChanged(<String>[...value, task]);
  }

  void _onRemove(int index) {
    final next = <String>[...value]..removeAt(index);
    onChanged(next);
  }

  /// 拖动改顺序：往下拖时要减 1，这是 ReorderableListView 的老规矩。
  void _onReorder(int oldIndex, int newIndex) {
    if (!enabled) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) {
      return;
    }
    final next = <String>[...value];
    next.insert(newIndex, next.removeAt(oldIndex));
    onChanged(next);
  }
}
