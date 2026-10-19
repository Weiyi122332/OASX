import 'dart:typed_data';

class LogApiException implements Exception {
  const LogApiException(this.operation, this.message, [this.statusCode]);
  final String operation;
  final String message;
  final int? statusCode;

  @override
  String toString() =>
      '$operation失败${statusCode == null ? '' : '（HTTP $statusCode）'}：$message';
}

Map<String, dynamic> requireLogJsonResponse({
  required String operation,
  required bool success,
  required dynamic data,
  required Map<String, Type> fields,
  int? statusCode,
  String? error,
}) {
  if (!success || (statusCode != null && statusCode >= 400)) {
    throw LogApiException(
      operation,
      error?.isNotEmpty == true ? error! : '日志请求未成功',
      statusCode,
    );
  }
  if (data is! Map) {
    throw LogApiException(operation, '服务器返回的日志格式无效', statusCode);
  }
  final map = Map<String, dynamic>.from(data);
  for (final entry in fields.entries) {
    final value = map[entry.key];
    final valid = entry.value == List
        ? value is List
        : entry.value == Map
        ? value is Map
        : entry.value == String
        ? value is String
        : false;
    if (!valid) {
      throw LogApiException(operation, '服务器返回的日志字段无效：${entry.key}', statusCode);
    }
  }
  return map;
}

Uint8List requireLogImageResponse(dynamic payload, int? statusCode) {
  var data = payload;
  if (payload is Map) {
    final code = payload['code'];
    if (code is int) statusCode = code;
    final error = payload['error']?.toString();
    if ((statusCode != null && statusCode >= 400) ||
        (error != null && error.isNotEmpty)) {
      throw LogApiException(
        '下载错误截图',
        error?.isNotEmpty == true ? error! : '截图请求未成功',
        statusCode,
      );
    }
    data = payload['data'];
  }
  if (statusCode != null && statusCode >= 400) {
    throw LogApiException('下载错误截图', '截图请求未成功', statusCode);
  }
  if (data is! List ||
      data.isEmpty ||
      data.any((v) => v is! int || v < 0 || v > 255)) {
    throw LogApiException('下载错误截图', '服务器没有返回有效的图片数据', statusCode);
  }
  return Uint8List.fromList(data.cast<int>());
}
