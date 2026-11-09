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
  });

  final List<String> value;
  final List<String> options;
  final ValueChanged<List<String>> onChanged;
  final String? errorText;
  final bool enabled;
  final int? maxSelections;
  final String Function(String)? optionLabel;

  static const double _menuMaxHeight = 288;

  @override
  Widget build(BuildContext context) {
    final selected = value.toSet();
    String display(String option) => optionLabel?.call(option) ?? option.tr;
    final label = options.where(selected.contains).map(display).join(', ');

    return MenuAnchor(
      menuChildren: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _menuMaxHeight),
          child: SingleChildScrollView(
            primary: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options
                  .map((option) {
                    final isSelected = selected.contains(option);
                    return MenuItemButton(
                      closeOnActivate: false,
                      trailingIcon: IgnorePointer(
                        child: Checkbox(value: isSelected, onChanged: (_) {}),
                      ),
                      onPressed: enabled
                          ? () {
                              final next = selected.toSet();
                              if (isSelected) {
                                next.remove(option);
                              } else {
                                if (maxSelections == 1) next.clear();
                                if (maxSelections != null &&
                                    next.length >= maxSelections!) {
                                  return;
                                }
                                next.add(option);
                              }
                              onChanged(
                                options
                                    .where(next.contains)
                                    .toList(growable: false),
                              );
                            }
                          : null,
                      child: Text(
                        display(option),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ],
      builder: (context, controller, child) {
        return InkWell(
          onTap: enabled
              ? () => controller.isOpen ? controller.close() : controller.open()
              : null,
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            isEmpty: label.isEmpty,
            decoration: InputDecoration(
              errorText: errorText,
              enabled: enabled,
              suffixIcon: Icon(
                controller.isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              ),
            ),
            child: Text(
              label.isEmpty ? ' ' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        );
      },
    );
  }
}
