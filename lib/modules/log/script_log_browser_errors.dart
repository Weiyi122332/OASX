part of 'script_log_browser_controller.dart';

/// Error list refresh cadence while the list page is visible.
const Duration _errorListRefreshInterval = Duration(seconds: 5);

extension ScriptLogBrowserErrorsX on ScriptLogBrowserController {
  Future<ErrorLogSummary> errorSummary(ScriptErrorLogItem item) {
    final key = '${item.id}:${item.logSize}';
    if (errorSummaries.length > 256) errorSummaries.clear();
    return errorSummaries.putIfAbsent(key, () async {
      try {
        final detail = await ApiClient().getScriptErrorLogDetail(
          item.id,
          logLimitBytes: 1048576,
        );
        return ErrorLogSummary.parse(
          detail.log.content,
          truncated: detail.log.truncated,
        );
      } catch (error) {
        errorSummaries.remove(key);
        return ErrorLogSummary('任务信息读取失败', error.toString());
      }
    });
  }

  /// No Markdown or image payload is produced before this action is invoked.
  Future<void> exportErrorReport() async {
    final detail = selectedErrorDetail.value;
    if (detail == null || exportingErrorReport.value) return;
    final attachSettings = includeErrorTaskSettings.value;
    exportingErrorReport.value = true;
    try {
      final settings = attachSettings
          ? await loadErrorTaskSettings(
              detail,
              load: (config, task) async {
                final exported = await ApiClient().exportTaskJson(
                  configName: config,
                  taskName: task,
                );
                final payload = jsonDecode(utf8.decode(exported.bytes));
                if (payload is! Map ||
                    payload.length != 1 ||
                    payload.values.single is! Map) {
                  return const ErrorTaskSettings({});
                }
                Map<String, dynamic> schema = {};
                try {
                  schema = await ApiClient().getScriptTask(
                    config,
                    task,
                    fresh: true,
                  );
                } catch (_) {
                  // Labels are optional; redacted values can still be rendered.
                }
                return ErrorTaskSettings(
                  Map<String, dynamic>.from(payload.values.single as Map),
                  schema: schema,
                );
              },
            )
          : const ErrorTaskSettings({});
      final images = <ScriptErrorImageBytes>[];
      for (final image in detail.images) {
        images.add(
          await ApiClient().getScriptErrorImage(detail.id, image.name),
        );
      }
      final bytes = Uint8List.fromList(
        utf8.encode(
          buildErrorMarkdown(
            detail,
            images,
            includeTaskSettings: attachSettings,
            taskSettings: settings,
            translate: (text) => text.tr,
          ),
        ),
      );
      final name = 'oasx-error-${detail.timestampMs}.md';
      if (kIsWeb) {
        await downloadBytesToBrowser(
          bytes,
          name,
          mimeType: 'text/markdown;charset=utf-8',
        );
      } else {
        final path = await FilePicker.platform.saveFile(
          fileName: name,
          type: FileType.custom,
          allowedExtensions: const ['md'],
          bytes: bytes,
        );
        if (path == null || path.trim().isEmpty) return;
        if (!_isMobileTargetPlatform()) await saveBytesToPath(path, bytes);
      }
      Get.snackbar('错误报告', 'Markdown 已保存（包含内嵌截图）');
    } catch (error) {
      Get.snackbar('导出失败', error.toString());
    } finally {
      exportingErrorReport.value = false;
    }
  }

  /// Loads one page of error logs for the current script.
  Future<void> loadErrorList({bool reset = false}) async {
    if (errorListLoading.value && !reset) {
      return;
    }
    if (!reset && !errorHasMore.value) {
      return;
    }
    final requestId = reset ? ++revision : revision;
    final cursor = reset ? null : errorNextCursor;
    _errorListRequestId = requestId;
    errorListLoading.value = true;
    errorMessage.value = '';
    if (reset) {
      errorNextCursor = null;
      errorHasMore.value = false;
    }
    try {
      final page = await ApiClient().getScriptErrorLogs(
        scriptName: scriptName,
        cursor: cursor,
      );
      if (!isErrorListLoadActive(requestId)) {
        return;
      }
      if (reset) {
        errorItems.assignAll(page.items);
      } else {
        errorItems.addAll(page.items);
      }
      errorNextCursor = page.nextCursor;
      errorHasMore.value = page.hasMore;
      if (selectedErrorId.value.isEmpty && page.items.isNotEmpty) {
        errorDetailVisible.value = false;
      }
    } catch (error) {
      if (isErrorListLoadActive(requestId)) {
        errorMessage.value = error.toString();
      }
    } finally {
      if (isErrorListLoadActive(requestId)) {
        errorListLoading.value = false;
      }
      if (_errorListRequestId == requestId) {
        _errorListRequestId = 0;
      }
    }
  }

  /// Starts background refresh for the visible error list page.
  void startErrorListAutoRefresh() {
    errorListRefreshTimer ??= Timer.periodic(
      _errorListRefreshInterval,
      (_) => refreshVisibleErrorList(),
    );
  }

  /// Stops background error-list refresh.
  void stopErrorListAutoRefresh() {
    errorListRefreshTimer?.cancel();
    errorListRefreshTimer = null;
  }

  /// Refreshes the error list when it is the visible page.
  void refreshVisibleErrorList() {
    if (activeTab.value != ScriptLogBrowserTab.error) {
      return;
    }
    if (errorDetailVisible.value) {
      return;
    }
    unawaited(loadErrorList(reset: true));
  }

  /// Loads detail for one selected error id.
  Future<void> selectError(String errorId) async {
    final normalized = errorId.trim();
    if (normalized.isEmpty) {
      return;
    }
    ScriptErrorLogItem? selectedItem;
    for (final item in errorItems) {
      if (item.id == normalized) {
        selectedItem = item;
        break;
      }
    }
    final requestId = revision;
    final renderToken = ++_errorDetailRenderToken;
    _errorDetailRequestId = requestId;
    selectedErrorId.value = normalized;
    selectedErrorTitle.value = selectedItem == null
        ? ''
        : formatErrorTimestamp(selectedItem.timestampMs, selectedItem.time);
    resetSelectedErrorRenderState();
    selectedErrorDetail.value = null;
    errorDetailVisible.value = true;
    errorDetailLoading.value = true;
    errorMessage.value = '';
    resetErrorDetailViewport?.call();
    try {
      final fetched = await ApiClient().getScriptErrorLogDetail(
        normalized,
        logLimitBytes: 1048576,
      );
      final detail = fetched.withScriptName(
        fetched.scriptName ?? selectedItem?.scriptName,
      );
      if (!isErrorDetailLoadActive(requestId) ||
          selectedErrorId.value != normalized) {
        return;
      }
      selectedErrorDetail.value = detail;
      scheduleSelectedErrorLogPreparation(
        detail: detail,
        renderToken: renderToken,
      );
    } catch (error) {
      if (isErrorDetailLoadActive(requestId)) {
        errorMessage.value = error.toString();
      }
    } finally {
      if (isErrorDetailLoadActive(requestId)) {
        errorDetailLoading.value = false;
      }
      if (_errorDetailRequestId == requestId) {
        _errorDetailRequestId = 0;
      }
    }
  }

  /// Copies the selected error log text.
  void copySelectedErrorLog() {
    final text = selectedErrorLogText.isEmpty
        ? selectedErrorDetail.value?.log.content ?? ''
        : selectedErrorLogText;
    copyText(text);
  }

  /// Returns to the error list page.
  void backToErrorList() {
    cancelSelectedErrorRenderWork();
    errorDetailVisible.value = false;
    refreshVisibleErrorList();
  }

  /// Formats one error timestamp for list and detail headers.
  String formatErrorTimestamp(int timestamp, String fallback) {
    if (timestamp <= 0) {
      return fallback;
    }
    final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${time.year.toString().padLeft(4, '0')}-'
        '${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }

  /// Returns whether one error image download is running.
  bool isErrorImageDownloading(ScriptErrorImageInfo image) {
    return downloadingImageKeys.contains(errorImageDownloadKey(image));
  }

  /// Builds a stable key for the selected error image.
  String errorImageDownloadKey(ScriptErrorImageInfo image) {
    final detailId = selectedErrorDetail.value?.id ?? selectedErrorId.value;
    return '$detailId/${image.name}';
  }

  /// Downloads one error image.
  Future<void> downloadErrorImage(ScriptErrorImageInfo image) async {
    final detail = selectedErrorDetail.value;
    if (detail == null) {
      return;
    }
    final downloadKey = '${detail.id}/${image.name}';
    if (downloadingImageKeys.contains(downloadKey)) {
      return;
    }
    downloadingImageKeys.add(downloadKey);
    try {
      final payload = await ApiClient().getScriptErrorImage(
        detail.id,
        image.name,
      );
      if (kIsWeb) {
        await downloadBytesToBrowser(
          payload.bytes,
          payload.fileName,
          mimeType: 'image/png',
        );
        Get.snackbar(
          I18n.tip.tr,
          I18n.homeLogImageSaveSuccess.tr,
          duration: const Duration(seconds: 1),
        );
        return;
      }
      final path = await FilePicker.platform.saveFile(
        fileName: payload.fileName,
        type: FileType.image,
        allowedExtensions: const ['png'],
        bytes: payload.bytes,
      );
      if (path == null || path.trim().isEmpty) {
        return;
      }
      if (!_isMobileTargetPlatform()) {
        await saveBytesToPath(path, payload.bytes);
      }
      Get.snackbar(
        I18n.tip.tr,
        I18n.homeLogImageSaveSuccess.tr,
        duration: const Duration(seconds: 1),
      );
    } catch (_) {
      Get.snackbar(
        I18n.tip.tr,
        I18n.homeLogImageSaveFailed.tr,
        duration: const Duration(seconds: 2),
      );
    } finally {
      downloadingImageKeys.remove(downloadKey);
    }
  }

  /// Returns whether the current runtime target is mobile.
  bool _isMobileTargetPlatform() {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
