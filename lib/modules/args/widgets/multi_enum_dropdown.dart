part of args;

class MultiEnumDropdown extends StatelessWidget {
  const MultiEnumDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
    this.maxSelections,
    this.optionLabel,
    this.semanticLabel,
  });

  final List<String> value;
  final List<String> options;
  final ValueChanged<List<String>> onChanged;
  final String? errorText;
  final bool enabled;
  final int? maxSelections;
  final String Function(String)? optionLabel;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final selected = value.toSet();
    final atLimit = maxSelections != null && selected.length >= maxSelections!;
    return WorkbenchSelect<String>.multiple(
      options: options,
      selectedValues: selected,
      optionLabel: optionLabel ?? (option) => option.tr,
      semanticLabel: semanticLabel,
      hintText: I18n.argsChooseOptions.tr,
      errorText: errorText,
      optionEnabled: (option) =>
          selected.contains(option) || maxSelections == 1 || !atLimit,
      onChanged: !enabled
          ? null
          : (option) {
              final next = selected.toSet();
              if (!next.remove(option)) {
                if (maxSelections == 1) next.clear();
                next.add(option);
              }
              onChanged(options.where(next.contains).toList(growable: false));
            },
    );
  }
}
