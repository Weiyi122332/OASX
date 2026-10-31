part of 'api_client.dart';

extension ApiClientResourcesX on ApiClient {
  Future<ResourceInventoryResponse> getResourceInventory(
    String scriptName, {
    String? dateKey,
  }) async {
    final suffix = dateKey == null
        ? ''
        : '?date=${Uri.encodeQueryComponent(dateKey)}';
    final result = await request(
      () => get(
        '/resources/${Uri.encodeComponent(scriptName)}$suffix',
        options: _statisticsNoCacheOptions(),
      ),
    );
    if (!result.isSuccess || result.data is! Map) {
      throw Exception(result.error ?? 'Invalid resource snapshot response');
    }
    return ResourceInventoryResponse.fromJson(
      Map<String, dynamic>.from(result.data),
    );
  }
}
