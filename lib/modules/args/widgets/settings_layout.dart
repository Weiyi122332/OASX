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
  const _SettingsPanel(this.id, this.title, this.groups);

  final String id;
  final String title;
  final List<_SettingsFields> groups;
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

  void addPanel(String id, String title, dynamic specs) {
    if (specs is! List) return;
    final fields = <_SettingsFields>[];
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
    if (fields.isNotEmpty) result.add(_SettingsPanel(id, title, fields));
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
          for (final variant in variants.whereType<Map>()) {
            final key = variant['id'];
            if (key is! String) continue;
            final label = _settingsText(variant['label'], key.tr);
            addPanel('$id-$key', '$title · $label', variant['groups']);
          }
        } else {
          addPanel(id, title, section['groups']);
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
