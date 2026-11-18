import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A controlled choice field for forms, filters, and navigation.
class WorkbenchSelect<T> extends StatefulWidget {
  WorkbenchSelect({
    super.key,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    T? value,
    this.hintText,
    this.semanticLabel,
    this.leadingIcon,
    this.errorText,
    this.visibleItems = 6,
  }) : selectedValues = value == null ? <T>[] : [value],
       multiple = false,
       optionEnabled = null;

  const WorkbenchSelect.multiple({
    super.key,
    required this.options,
    required this.selectedValues,
    required this.optionLabel,
    required this.onChanged,
    this.optionEnabled,
    this.hintText,
    this.semanticLabel,
    this.leadingIcon,
    this.errorText,
    this.visibleItems = 6,
  }) : multiple = true;

  final Iterable<T> options;
  final Iterable<T> selectedValues;
  final String Function(T) optionLabel;
  final ValueChanged<T>? onChanged;
  final bool Function(T)? optionEnabled;
  final bool multiple;
  final String? hintText;
  final String? semanticLabel;
  final IconData? leadingIcon;
  final String? errorText;
  final int visibleItems;

  @override
  State<WorkbenchSelect<T>> createState() => _WorkbenchSelectState<T>();
}

class _WorkbenchSelectState<T> extends State<WorkbenchSelect<T>> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedValues.toSet();
    final options = widget.options.toList(growable: false);
    final labels = options.where(selected.contains).map(widget.optionLabel);
    final enabled = options.isNotEmpty && widget.onChanged != null;
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = math.max(
          0.0,
          MediaQuery.sizeOf(context).width - 16,
        );
        final menuWidth = math.min(constraints.maxWidth, availableWidth);
        final menuLimit = math.max(menuWidth, math.min(280.0, availableWidth));
        return MenuAnchor(
          crossAxisUnconstrained: false,
          childFocusNode: _focus,
          alignmentOffset: const Offset(0, 4),
          style: MenuStyle(
            minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
            maximumSize: WidgetStatePropertyAll(
              Size(
                menuLimit,
                widget.visibleItems * kMinInteractiveDimension + 12,
              ),
            ),
          ),
          menuChildren: [
            for (final option in options)
              Semantics(
                selected: widget.multiple ? null : selected.contains(option),
                checked: widget.multiple ? selected.contains(option) : null,
                child: MenuItemButton(
                  closeOnActivate: !widget.multiple,
                  onPressed:
                      enabled && (widget.optionEnabled?.call(option) ?? true)
                      ? () => widget.onChanged!(option)
                      : null,
                  style: selected.contains(option)
                      ? MenuItemButton.styleFrom(
                          backgroundColor: colors.secondaryContainer,
                          foregroundColor: colors.onSecondaryContainer,
                        )
                      : null,
                  trailingIcon: selected.contains(option)
                      ? const Icon(Icons.check_rounded, size: 18)
                      : const SizedBox(width: 18),
                  child: Text(widget.optionLabel(option), softWrap: true),
                ),
              ),
          ],
          builder: (context, menu, _) => WorkbenchPickerField(
            text: labels.join(', '),
            hintText: widget.hintText,
            semanticLabel: widget.semanticLabel,
            leadingIcon: widget.leadingIcon,
            trailingIcon: menu.isOpen
                ? Icons.expand_less_rounded
                : Icons.expand_more_rounded,
            errorText: widget.errorText,
            expanded: menu.isOpen,
            focusNode: _focus,
            onPressed: enabled
                ? () {
                    if (menu.isOpen) {
                      menu.close();
                    } else {
                      _focus.requestFocus();
                      menu.open();
                    }
                  }
                : null,
          ),
        );
      },
    );
  }
}

/// A keyboard-accessible input that opens a menu or date/time picker.
class WorkbenchPickerField extends StatefulWidget {
  const WorkbenchPickerField({
    super.key,
    required this.text,
    required this.trailingIcon,
    required this.onPressed,
    this.hintText,
    this.semanticLabel,
    this.leadingIcon,
    this.errorText,
    this.expanded,
    this.focusNode,
  });

  final String text;
  final String? hintText;
  final String? semanticLabel;
  final IconData? leadingIcon;
  final IconData trailingIcon;
  final String? errorText;
  final bool? expanded;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;

  @override
  State<WorkbenchPickerField> createState() => _WorkbenchPickerFieldState();
}

class _WorkbenchPickerFieldState extends State<WorkbenchPickerField> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = widget.onPressed != null;
    final hasValue = widget.text.isNotEmpty;
    return Semantics(
      button: true,
      enabled: enabled,
      expanded: widget.expanded,
      label: widget.semanticLabel,
      child: InkWell(
        focusNode: widget.focusNode,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onHover: (hovered) => setState(() => _hovered = hovered),
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onPressed,
        child: InputDecorator(
          isFocused: _focused || widget.expanded == true,
          isHovering: _hovered,
          decoration: InputDecoration(
            enabled: enabled,
            errorText: widget.errorText,
            prefixIcon: widget.leadingIcon == null
                ? null
                : Icon(widget.leadingIcon, size: 19),
            suffixIcon: Icon(widget.trailingIcon, size: 20),
          ),
          child: Text(
            hasValue ? widget.text : widget.hintText ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: !enabled
                  ? theme.disabledColor
                  : hasValue
                  ? colors.onSurface
                  : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
