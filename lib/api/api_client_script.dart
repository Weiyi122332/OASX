part of 'api_client.dart';

extension ApiClientScriptX on ApiClient {
  /// Loads the full argument model for one task.
  Future<Map<String, dynamic>> getScriptTask(
    String scriptName,
    String taskName,
  ) async {
    final res = await request(() => get('/$scriptName/$taskName/args'));
    return res.data ?? {};
  }

  /// Persists one task argument through the generic value endpoint.
  Future<bool> putScriptArg(
    String scriptName,
    String taskName,
    String groupName,
    String argumentName,
    String type,
    dynamic value,
  ) async {
    // 列表类型的参数（多选下拉、任务组的任务列表）要按 JSON 数组传给服务端
    final encodedValue =
        listArgumentTypes.contains(type) ? jsonEncode(value) : value;
    final res = await request(
      () => put(
        '/$scriptName/$taskName/$groupName/$argumentName/value',
        queryParameters: {'types': type, 'value': encodedValue},
      ),
    );
    return res.isSuccess && res.data == true;
  }

  /// Synchronizes one task back into the waiting queue immediately.
  Future<bool> syncScriptTaskNextRun(
    String scriptName,
    String taskName,
    String targetDt,
  ) async {
    final res = await request(
      () => put(
        '/$scriptName/$taskName/sync_next_run',
        queryParameters: {'target_dt': targetDt},
      ),
    );
    return res.isSuccess && res.data == true;
  }
}
