import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/common/widgets/add_config_dialog.dart';
import 'package:oasx/modules/common/widgets/appbar.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/widgets/config_workbench.dart';
import 'package:oasx/modules/server/controllers/server_controller.dart';
import 'package:oasx/service/script_service.dart';
import 'package:oasx/translation/i18n_content.dart';
import 'package:oasx/utils/check_version.dart';
import 'package:oasx/utils/platform_utils.dart';

part 'home_view_actions.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key, this.standalone = true, this.onOpenSettings});

  final bool standalone;
  final VoidCallback? onOpenSettings;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final scriptService = Get.find<ScriptService>();
  final controller = Get.find<HomeDashboardController>();
  bool _isAddingScript = false;
  bool _isRefreshingScripts = false;

  void _openSettings() {
    final open = widget.onOpenSettings;
    if (open != null) {
      open();
    } else {
      Get.toNamed('/settings');
    }
  }

  void _setAddingScript(bool value) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isAddingScript = value;
    });
  }

  void _setRefreshingScripts(bool value) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isRefreshingScripts = value;
    });
  }

  @override
  void initState() {
    super.initState();
    if (!PlatformUtils.isWeb) {
      Future.delayed(const Duration(milliseconds: 300), () {
        checkUpdate();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.checkStartupConnection();
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      child: Stack(
        children: [
          _buildDashboardBody(),
          Obx(() {
            final message = controller.startupLoadingMessage.value;
            if (message.isEmpty) {
              return const SizedBox.shrink();
            }
            return Positioned.fill(
              child: _StartupLoadingOverlay(
                message: message,
                autoDeploying: controller.isStartupAutoDeploying.value,
              ),
            );
          }),
        ],
      ),
    );

    if (!widget.standalone) {
      return body;
    }

    return Scaffold(
      appBar: buildPlatformAppBar(
        context,
        routePath: '/home',
        trailingActions: PlatformUtils.usesDesktopLayout
            ? [
                IconButton(
                  tooltip: I18n.setting.tr,
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_rounded),
                ),
              ]
            : const [],
      ),
      body: body,
    );
  }
}

class _StartupLoadingOverlay extends StatelessWidget {
  const _StartupLoadingOverlay({
    required this.message,
    required this.autoDeploying,
  });

  final String message;
  final bool autoDeploying;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: 32,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message.tr,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (autoDeploying) const _AutoDeployStatusView(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AutoDeployStatusView extends StatelessWidget {
  const _AutoDeployStatusView();

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ServerController>()) {
      return const SizedBox.shrink();
    }
    final controller = Get.find<ServerController>();
    return Obx(() {
      final log = controller.latestLog.value.trim();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (log.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              log,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Get.toNamed('/server'),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(I18n.homeGoDeployPage.tr),
          ),
        ],
      );
    });
  }
}
