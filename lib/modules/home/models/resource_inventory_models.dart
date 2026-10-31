import 'package:intl/intl.dart';

class ResourceBalance {
  const ResourceBalance({
    required this.quantity,
    required this.display,
    required this.exact,
    required this.error,
  });

  factory ResourceBalance.fromJson(Map<String, dynamic> json) =>
      ResourceBalance(
        quantity: (json['quantity'] as num?)?.toInt(),
        display: json['display']?.toString() ?? '',
        exact: json['exact'] == true,
        error: json['error']?.toString() ?? '',
      );

  final int? quantity;
  final String display;
  final bool exact;
  final String error;

  String get formatted => quantity == null
      ? '—'
      : exact
      ? NumberFormat.decimalPattern().format(quantity)
      : display;
}

class ResourceSnapshot {
  ResourceSnapshot.fromJson(Map<String, dynamic> json)
    : capturedAt = DateTime.tryParse(json['captured_at']?.toString() ?? ''),
      status = json['status']?.toString() ?? 'partial',
      resources = {
        for (final entry in (json['resources'] as Map? ?? {}).entries)
          entry.key.toString(): ResourceBalance.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      };

  final DateTime? capturedAt;
  final String status;
  final Map<String, ResourceBalance> resources;

  String get capturedAtLabel {
    final value = capturedAt;
    if (value == null) return '—';
    return DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(value.toUtc().add(const Duration(hours: 8)));
  }
}

class ResourceInventoryResponse {
  ResourceInventoryResponse.fromJson(Map<String, dynamic> json)
    : snapshot = json['snapshot'] is Map
          ? ResourceSnapshot.fromJson(
              Map<String, dynamic>.from(json['snapshot']),
            )
          : null,
      dates = (json['dates'] as List? ?? []).map((value) => '$value').toList(),
      enabled = (json['schedule'] as Map?)?['enabled'] == true,
      cron = (json['schedule'] as Map?)?['cron']?.toString() ?? '';

  final ResourceSnapshot? snapshot;
  final List<String> dates;
  final bool enabled;
  final String cron;
}
