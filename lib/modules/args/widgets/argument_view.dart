part of args;

class ArgumentView extends StatefulWidget {
  const ArgumentView({
    required this.setArgument,
    required this.getGroupName,
    this.displayTitle,
    required this.index,
    this.lockImmediateScheduling = false,
    Key? key,
    this.scriptName,
    this.taskName,
  }) : super(key: key);

  final SetArgumentCallback setArgument;
  final String Function() getGroupName;
  final String? displayTitle;
  final int index;
  final bool lockImmediateScheduling;
  final String? scriptName;
  final String? taskName;

  @override
  State<ArgumentView> createState() => _ArgumentViewState();
}

class _ArgumentViewState extends State<ArgumentView> {
  Timer? timer;
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  ArgumentModel get model {
    final controller = Get.find<ArgsController>();
    final groupsModel = controller.groupsData.value[widget.getGroupName()];
    return groupsModel!.members[widget.index];
  }

  ArgsController get _argsController => Get.find<ArgsController>();

  bool get _isProtectedImmediateScheduleField {
    return widget.lockImmediateScheduling &&
        ArgsController.isImmediateSchedulingField(
          widget.getGroupName(),
          model.title,
        );
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: model.value.toString());
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    timer?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!_argsController._isArgumentVisible(widget.getGroupName(), model)) {
        return const SizedBox.shrink();
      }
      _syncTextController();
      final title = _title();
      final form = _buildFormSection();
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >=
                MediaQuery.textScalerOf(context).scale(440)) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: title),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: form),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [title, const SizedBox(height: 6), form],
            );
          },
        ),
      );
    });
  }

  Widget _title() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          widget.displayTitle ?? model.displayTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (model.displayDescription.isNotEmpty)
          SelectableText(
            model.displayDescription,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ).padding(top: 4),
      ],
    );
  }

  Widget _buildFormSection() {
    final errorText = _argsController.fieldError(
      widget.getGroupName(),
      model.title,
    );
    final isLocked = _isProtectedImmediateScheduleField;
    final child = switch (model.type) {
      'boolean' => Checkbox(
        value: model.value,
        onChanged: isLocked ? null : onCheckboxChanged,
      ).alignment(Alignment.centerLeft),
      'string' => _buildTextField(errorText: errorText, enabled: !isLocked),
      'multi_line' => _buildTextField(
        errorText: errorText,
        maxLines: null,
        enabled: !isLocked,
      ),
      'number' => _buildTextField(
        errorText: errorText,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[-0-9.]'))],
        onChanged: _scheduleNumberChange,
        enabled: !isLocked,
      ),
      'integer' => _buildTextField(
        errorText: errorText,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[-0-9]'))],
        onChanged: _scheduleIntegerChange,
        enabled: !isLocked,
      ),
      'enum' => WorkbenchSelect<String>(
        value: model.value.toString(),
        options: model.enumEnum ?? const <String>[],
        optionLabel: model.displayOption,
        semanticLabel: widget.displayTitle ?? model.displayTitle,
        hintText: I18n.argsChooseOptions.tr,
        errorText: errorText,
        onChanged: isLocked ? null : onEnumChanged,
      ),
      'multi_enum' => MultiEnumDropdown(
        value: ArgumentModel.normalizeMultiEnumValue(model.value),
        options: model.enumEnum ?? const <String>[],
        errorText: errorText,
        enabled: !isLocked,
        maxSelections: model.maxItems,
        optionLabel: model.displayOption,
        semanticLabel: widget.displayTitle ?? model.displayTitle,
        onChanged: onMultiEnumChanged,
      ),
      'task_list' => TaskListEditor(
        value: ArgumentModel.normalizeMultiEnumValue(model.value),
        options: model.enumEnum ?? const <String>[],
        maxCount: model.maxItems,
        errorText: errorText,
        enabled: !isLocked,
        onChanged: onTaskListChanged,
      ),
      'date_time' => DateTimePicker(
        value: model.value,
        onChange: onDateTimeChanged,
        fieldIcon: Icons.calendar_month_outlined,
        enabled: !isLocked,
        errorText: errorText,
        semanticLabel: widget.displayTitle ?? model.displayTitle,
      ),
      'time_delta' => TimeDeltaPicker(
        value: ensureTimeDeltaString(model.value),
        onChange: onTimeDeltaChanged,
        fieldIcon: Icons.timer_outlined,
        enabled: !isLocked,
        errorText: errorText,
        semanticLabel: widget.displayTitle ?? model.displayTitle,
      ),
      'time' => TimePicker(
        value: model.value,
        onChange: onTimeChanged,
        fieldIcon: Icons.schedule_rounded,
        enabled: !isLocked,
        errorText: errorText,
        semanticLabel: widget.displayTitle ?? model.displayTitle,
      ),
      _ => Text(model.value.toString()),
    };
    return child;
  }

  Widget _buildTextField({
    required String? errorText,
    bool enabled = true,
    int? maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isSingleLine = maxLines == 1;
    return TextFormField(
      controller: _textController,
      focusNode: _focusNode,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      scrollPadding: EdgeInsets.only(
        left: 12,
        top: 12,
        right: 12,
        bottom: keyboardInset > 0 ? keyboardInset + 24 : 24,
      ),
      textInputAction: isSingleLine
          ? TextInputAction.done
          : TextInputAction.newline,
      decoration: InputDecoration(errorText: errorText),
      onTapOutside: PlatformUtils.isWeb ? null : (_) => _focusNode.unfocus(),
      onEditingComplete: PlatformUtils.isWeb
          ? null
          : (isSingleLine ? _focusNode.unfocus : null),
      onChanged: onChanged ?? _scheduleStringChange,
    );
  }

  void _syncTextController() {
    if (_focusNode.hasFocus) {
      return;
    }
    final nextValue = model.value.toString();
    if (_textController.text == nextValue) {
      return;
    }
    _textController.value = TextEditingValue(
      text: nextValue,
      selection: TextSelection.collapsed(offset: nextValue.length),
    );
  }

  void _scheduleStringChange(String value) {
    timer?.cancel();
    timer = Timer(
      const Duration(milliseconds: 150),
      () => onStringChanged(value),
    );
  }

  void _scheduleNumberChange(String value) {
    timer?.cancel();
    timer = Timer(
      const Duration(milliseconds: 150),
      () => onNumberChanged(value),
    );
  }

  void _scheduleIntegerChange(String value) {
    timer?.cancel();
    timer = Timer(
      const Duration(milliseconds: 150),
      () => onIntegerChanged(value),
    );
  }
}
