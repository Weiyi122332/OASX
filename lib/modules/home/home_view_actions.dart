part of 'index.dart';

extension _HomeViewActions on _HomeViewState {
  Widget _buildDashboardBody() {
    return Obx(() {
      if (controller.startupLoadingMessage.value.isNotEmpty) {
        return const SizedBox.expand();
      }
      if (controller.isStartupConnectionFailed.value &&
          scriptService.scriptOrderList.isEmpty) {
        return _buildConnectionFailedView();
      }
      return Padding(
        padding: const EdgeInsets.all(12),
        child: ConfigWorkbench(
          controller: controller,
          scriptService: scriptService,
          loadingAddScript: _isAddingScript,
          refreshingScripts: _isRefreshingScripts,
          onAddScriptTap: _onAddScriptCardTap,
          onRefreshScriptsTap: _onRefreshScriptsTap,
        ),
      );
    });
  }

  Widget _buildConnectionFailedView() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.cloud_off_outlined,
                        color: colors.onPrimaryContainer,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    I18n.homeDisconnected.tr,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    I18n.homeConnectionRetryHint.tr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            _isRefreshingScripts ||
                                controller.isStartupChecking.value
                            ? null
                            : _onRefreshScriptsTap,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(I18n.retry.tr),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openSettings,
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        label: Text(I18n.setting.tr),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onAddScriptCardTap() async {
    if (_isAddingScript) {
      return;
    }
    final createdConfig = await showAddConfigDialog(
      context,
      onSubmitting: () => _setAddingScript(true),
      onSubmitDone: () {
        _setAddingScript(false);
        controller.syncWorkspaceState();
      },
    );
    if (createdConfig == null || createdConfig.isEmpty) {
      return;
    }
    controller.setActiveScript(createdConfig);
  }

  Future<void> _onRefreshScriptsTap() async {
    if (_isRefreshingScripts) {
      return;
    }
    _setRefreshingScripts(true);
    try {
      await controller.retryStartupConnection();
      controller.syncWorkspaceState();
    } catch (_) {
      Get.snackbar(I18n.loginError.tr, I18n.loginErrorMsg.tr);
    } finally {
      _setRefreshingScripts(false);
    }
  }
}
