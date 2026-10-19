part of 'api_client.dart';

extension ApiClientLogsX on ApiClient {
  /// Loads latest or older script log window.
  Future<ScriptLogWindow> getScriptLogWindow(
    String scriptName, {
    String? cursor,
    int limitLines = 500,
    int limitBytes = 262144,
  }) async {
    final query = <String, dynamic>{
      'limit_lines': limitLines,
      'limit_bytes': limitBytes,
    };
    final normalizedCursor = cursor?.trim();
    if (normalizedCursor != null && normalizedCursor.isNotEmpty) {
      query['cursor'] = normalizedCursor;
    }
    final res = await request(
      () => get(
        '/logs/${Uri.encodeComponent(scriptName)}',
        queryParameters: query,
        options: _noCacheOptions(),
      ),
    );
    return ScriptLogWindow.fromJson(
      requireLogJsonResponse(
        operation: '读取运行日志',
        success: res.isSuccess,
        data: res.data,
        statusCode: res.code,
        error: res.error,
        fields: const {'lines': List},
      ),
    );
  }

  /// Builds script log SSE URI for live tailing.
  Uri buildScriptLogStreamUri(
    String scriptName, {
    String? cursor,
    int limitLines = 200,
    int limitBytes = 131072,
  }) {
    final base = _baseUri();
    final query = <String, String>{
      'limit_lines': limitLines.toString(),
      'limit_bytes': limitBytes.toString(),
    };
    final normalizedCursor = cursor?.trim();
    if (normalizedCursor != null && normalizedCursor.isNotEmpty) {
      query['cursor'] = normalizedCursor;
    }
    return base.replace(
      pathSegments: [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        'logs',
        scriptName,
        'stream',
      ],
      queryParameters: query,
    );
  }

  /// Loads one page of error logs.
  Future<ScriptErrorLogList> getScriptErrorLogs({
    String? date,
    String? scriptName,
    int limit = 100,
    String? cursor,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    final normalizedDate = date?.trim();
    if (normalizedDate != null && normalizedDate.isNotEmpty) {
      query['date'] = normalizedDate;
    }
    final normalizedScript = scriptName?.trim();
    var pageCursor = cursor?.trim();
    final visited = <String>{};
    while (true) {
      if (pageCursor != null && pageCursor.isNotEmpty) {
        query['cursor'] = pageCursor;
      }
      final res = await request(
        () => get(
          '/logs/errors',
          queryParameters: query,
          options: _noCacheOptions(),
        ),
      );
      final page = ScriptErrorLogList.fromJson(
        requireLogJsonResponse(
          operation: '读取错误日志列表',
          success: res.isSuccess,
          data: res.data,
          statusCode: res.code,
          error: res.error,
          fields: const {'items': List},
        ),
      );
      final items = <ScriptErrorLogItem>[];
      // Limit concurrent detail reads and cache only ownership metadata.
      for (var offset = 0; offset < page.items.length; offset += 4) {
        final batch = page.items.skip(offset).take(4).toList();
        final resolved = await Future.wait(
          batch.map(
            (item) => _errorOwnership.resolve(
              item,
              backend: address,
              loadDetail: (id) =>
                  getScriptErrorLogDetail(id, logLimitBytes: 1048576),
            ),
          ),
        );
        items.addAll(
          resolved.where(
            (item) =>
                normalizedScript == null ||
                normalizedScript.isEmpty ||
                errorLogBelongsInView(item, normalizedScript),
          ),
        );
      }
      final next = page.nextCursor;
      if (page.hasMore &&
          (next == null ||
              next.isEmpty ||
              next == pageCursor ||
              visited.contains(next))) {
        throw const LogApiException('读取错误日志列表', '服务器返回的翻页游标无效');
      }
      if (items.isNotEmpty || !page.hasMore) {
        return ScriptErrorLogList(
          date: page.date,
          scriptName: normalizedScript,
          items: items,
          nextCursor: next,
          hasMore: page.hasMore,
        );
      }
      // An entire page may belong to other configs. Continue rather than
      // incorrectly presenting an empty list while matching older errors exist.
      visited.add(next!);
      pageCursor = next;
    }
  }

  /// Loads one error log detail by id.
  Future<ScriptErrorLogDetail> getScriptErrorLogDetail(
    String errorId, {
    int logLimitBytes = 262144,
  }) async {
    final res = await request(
      () => get(
        '/logs/errors/${Uri.encodeComponent(errorId)}',
        queryParameters: {'log_limit_bytes': logLimitBytes},
        options: _noCacheOptions(),
      ),
    );
    return ScriptErrorLogDetail.fromJson(
      requireLogJsonResponse(
        operation: '读取错误日志详情',
        success: res.isSuccess,
        data: res.data,
        statusCode: res.code,
        error: res.error,
        fields: const {'id': String, 'log': Map, 'images': List},
      ),
    );
  }

  /// Downloads one error image as bytes.
  Future<ScriptErrorImageBytes> getScriptErrorImage(
    String errorId,
    String imageName,
  ) async {
    final response = await NetOptions.instance.dio.get<dynamic>(
      '/logs/errors/${Uri.encodeComponent(errorId)}/images/${Uri.encodeComponent(imageName)}',
      options: _noCacheOptions(responseType: ResponseType.bytes),
    );
    return ScriptErrorImageBytes(
      fileName: imageName,
      bytes: requireLogImageResponse(response.data, response.statusCode),
    );
  }

  /// Resolves the absolute image URI for display widgets.
  String buildScriptErrorImageUrl(String errorId, String imageName) {
    final base = _baseUri();
    return base
        .replace(
          pathSegments: [
            ...base.pathSegments.where((segment) => segment.isNotEmpty),
            'logs',
            'errors',
            errorId,
            'images',
            imageName,
          ],
        )
        .toString();
  }

  Options _noCacheOptions({ResponseType? responseType}) {
    final cacheOptions = _cacheOptions.copyWith(policy: CachePolicy.noCache);
    return Options(
      extra: cacheOptions.toExtra(),
      headers: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
      responseType: responseType,
    );
  }

  Uri _baseUri() {
    final normalized = address.trim().isEmpty
        ? ApiClient._defaultAddress
        : address.trim();
    return Uri.parse(normalized);
  }
}
