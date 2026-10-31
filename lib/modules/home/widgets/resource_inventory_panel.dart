import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/home/models/resource_inventory_models.dart';
import 'package:oasx/translation/i18n_content.dart';

typedef ResourceInventoryLoader =
    Future<ResourceInventoryResponse> Function(
      String scriptName,
      String? dateKey,
    );

class ResourceInventoryPanel extends StatefulWidget {
  const ResourceInventoryPanel({
    super.key,
    required this.scriptName,
    this.loader,
  });

  final String scriptName;
  final ResourceInventoryLoader? loader;

  @override
  State<ResourceInventoryPanel> createState() => _ResourceInventoryPanelState();
}

class _ResourceInventoryPanelState extends State<ResourceInventoryPanel> {
  ResourceInventoryResponse? _data;
  String? _selectedDate;
  String? _error;
  bool _loading = false;
  int _revision = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_load()),
    );
  }

  @override
  void didUpdateWidget(covariant ResourceInventoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scriptName != widget.scriptName) {
      _revision++;
      _data = null;
      _selectedDate = null;
      _error = null;
      _loading = false;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _revision++;
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || widget.scriptName.isEmpty) return;
    final revision = ++_revision;
    final scriptName = widget.scriptName;
    final selectedDate = _selectedDate;
    setState(() => _loading = true);
    try {
      final data =
          await (widget.loader?.call(scriptName, selectedDate) ??
              ApiClient().getResourceInventory(
                scriptName,
                dateKey: selectedDate,
              ));
      if (!mounted || revision != _revision) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (error) {
      if (!mounted || revision != _revision) return;
      setState(() => _error = '${I18n.resourceReadFailed.tr}\n$error');
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  void _selectDate(String? value) {
    final selected = value == 'latest' ? null : value;
    if (_selectedDate == selected) return;
    setState(() {
      _revision++;
      _loading = false;
      _selectedDate = selected;
      _data = null;
      _error = null;
    });
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _data;
    final snapshot = data?.snapshot;
    final dates = data?.dates ?? const <String>[];
    final schedule = data == null
        ? I18n.resourceSchedule.tr
        : !data.enabled
        ? I18n.resourceScheduleDisabled.tr
        : data.cron == '0 23 * * *'
        ? I18n.resourceSchedule.tr
        : I18n.resourceCustomSchedule.trParams({'cron': data.cron});
    return ListView(
      key: ValueKey('resource-panel-${widget.scriptName}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                I18n.homeResourcesTab.tr,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: I18n.resourceRefresh.tr,
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'resource-date-${widget.scriptName}-${_selectedDate ?? 'latest'}',
          ),
          initialValue: _selectedDate ?? 'latest',
          isExpanded: true,
          menuMaxHeight: 280,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: 'latest',
              child: Text(I18n.resourceLatest.tr),
            ),
            for (final date in {
              ...dates,
              if (_selectedDate != null) _selectedDate!,
            })
              DropdownMenuItem(value: date, child: Text(date)),
          ],
          onChanged: _selectDate,
        ),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        if (snapshot == null && !_loading && _error == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(I18n.resourceEmpty.tr, textAlign: TextAlign.center),
          ),
        if (snapshot != null) ...[
          Text(snapshot.capturedAtLabel, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 280
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final entry in <String, String>{
                    'coins': I18n.resourceCoins.tr,
                    'stamina': I18n.resourceStamina.tr,
                    'jade': I18n.resourceJade.tr,
                    'mystery_amulets': I18n.resourceAmulets.tr,
                  }.entries)
                    SizedBox(
                      width: width,
                      child: _ResourceCard(
                        resource: entry.key,
                        label: entry.value,
                        balance: snapshot.resources[entry.key],
                      ),
                    ),
                ],
              );
            },
          ),
          if (snapshot.status != 'complete') ...[
            const SizedBox(height: 10),
            Text(
              I18n.resourcePartial.tr,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
        const SizedBox(height: 16),
        Text(schedule, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.resource,
    required this.label,
    required this.balance,
  });

  final String resource;
  final String label;
  final ResourceBalance? balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = balance;
    final hint = value?.quantity == null
        ? I18n.resourceUnknown.tr
        : resource == 'mystery_amulets'
        ? I18n.resourceAmuletHint.tr
        : value!.exact
        ? ''
        : I18n.resourceCompact.tr;
    return Tooltip(
      message: value?.error ?? '',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/resources/$resource.png',
                  width: 32,
                  height: 32,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value?.formatted ?? '—',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 4),
            Text(hint.isEmpty ? ' ' : hint, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
