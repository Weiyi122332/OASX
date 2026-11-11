part of args;

String _settingsText(dynamic value, String fallback) {
  if (value is String) return value.tr;
  if (value is Map) {
    final locale = Get.locale?.toString().replaceAll('-', '_') ?? 'zh_CN';
    final translated = value[locale] ?? value['en_US'] ?? value['zh_CN'];
    if (translated is String && translated.isNotEmpty) return translated;
  }
  return fallback;
}

class _SettingsFields {
  const _SettingsFields(this.name, this.names, [this.labels = const {}]);

  final String name;
  final Set<String> names;
  final Map<dynamic, dynamic> labels;
}

class _SettingsPanel {
  const _SettingsPanel(
    this.id,
    this.title,
    this.groups, {
    this.variants = const [],
  });

  final String id;
  final String title;
  final List<_SettingsFields> groups;
  final List<_SettingsPanel> variants;
}

List<_SettingsPanel> _settingsPanels(
  Map<String, GroupsModel> groups,
  List<String> groupNames,
) {
  final remaining = {
    for (final name in groupNames)
      if (groups.containsKey(name))
        name: {
          for (final field in groups[name]!.members.cast<ArgumentModel>())
            if (!field.hidden) field.title,
        },
  };
  final result = <_SettingsPanel>[];

  List<_SettingsFields> takeFields(dynamic specs) {
    final fields = <_SettingsFields>[];
    if (specs is! List) return fields;
    for (final spec in specs.whereType<Map>()) {
      final name = spec['name'];
      final available = remaining[name];
      if (name is! String || available == null) continue;
      final filter = spec['fields'];
      final selected = filter is List
          ? available.intersection(filter.whereType<String>().toSet())
          : available.toSet();
      if (selected.isEmpty) continue;
      final labels = spec['labels'];
      fields.add(
        _SettingsFields(name, selected, labels is Map ? labels : const {}),
      );
      available.removeAll(selected);
    }
    return fields;
  }

  final settings = groups['settings_layout_config']?.members
      .cast<ArgumentModel>();
  if (settings != null) {
    for (final field in settings) {
      final layout = field.uiLayout;
      if (field.value != true || layout is! Map || layout['version'] != 1) {
        continue;
      }
      final sections = layout['sections'];
      if (sections is! List) continue;
      for (final section in sections.whereType<Map>()) {
        final id = section['id'];
        if (id is! String) continue;
        final title = _settingsText(section['title'], id.tr);
        final variants = section['variants'];
        if (variants is List && variants.isNotEmpty) {
          final variantPanels = <_SettingsPanel>[];
          final usePicker = section['select_variant'] == true;
          for (final variant in variants.whereType<Map>()) {
            final key = variant['id'];
            if (key is! String) continue;
            final label = _settingsText(variant['label'], key.tr);
            final fields = takeFields(variant['groups']);
            if (fields.isEmpty) continue;
            variantPanels.add(
              _SettingsPanel(
                '$id-$key',
                usePicker ? label : '$title · $label',
                fields,
              ),
            );
          }
          if (usePicker && variantPanels.isNotEmpty) {
            result.add(
              _SettingsPanel(id, title, const [], variants: variantPanels),
            );
          } else {
            result.addAll(variantPanels);
          }
        } else {
          final fields = takeFields(section['groups']);
          if (fields.isNotEmpty) result.add(_SettingsPanel(id, title, fields));
        }
      }
    }
  }

  for (final entry in remaining.entries) {
    if (entry.value.isEmpty) continue;
    final group = groups[entry.key]!;
    final title = group.members.cast<ArgumentModel>().first.groupTitle;
    result.add(
      _SettingsPanel('group-${entry.key}', _settingsText(title, entry.key.tr), [
        _SettingsFields(entry.key, entry.value),
      ]),
    );
  }
  return result;
}

class _SettingsVariantPicker extends StatefulWidget {
  const _SettingsVariantPicker({
    required this.variants,
    required this.buildFields,
  });

  final List<_SettingsPanel> variants;
  final Widget Function(_SettingsPanel) buildFields;

  @override
  State<_SettingsVariantPicker> createState() => _SettingsVariantPickerState();
}

class _SettingsVariantPickerState extends State<_SettingsVariantPicker> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final selected = widget.variants.any((variant) => variant.id == _selected)
        ? _selected!
        : widget.variants.first.id;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButton<String>(
            isExpanded: true,
            value: selected,
            onChanged: (value) => setState(() => _selected = value),
            items: [
              for (final variant in widget.variants)
                DropdownMenuItem(
                  value: variant.id,
                  child: Text(variant.title, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
        ),
        for (final variant in widget.variants)
          Visibility(
            key: ValueKey(variant.id),
            visible: variant.id == selected,
            maintainState: true,
            child: widget.buildFields(variant),
          ),
      ],
    );
  }
}
