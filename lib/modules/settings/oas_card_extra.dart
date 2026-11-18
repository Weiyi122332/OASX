import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:oasx/modules/common/widgets/workbench_dialog.dart';
import 'package:oasx/modules/home/updater_view.dart';
import 'package:oasx/modules/settings/controllers/settings_controller.dart';
import 'package:oasx/service/script_service.dart';
import 'package:oasx/translation/i18n_content.dart';

class AutoScriptButton extends StatelessWidget {
  const AutoScriptButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: I18n.autoRunScriptList.tr,
      onPressed: () => Get.dialog(
        WorkbenchDialog(
          title: I18n.autoRunScriptList.tr,
          content: const AutoScriptDialogContent(),
        ),
      ),
      icon: const Icon(Icons.settings_rounded),
    );
  }
}

void updater() {
  Get.dialog(
    WorkbenchDialog(
      title: I18n.updater.tr,
      width: 700,
      content: const UpdaterView(),
    ),
  );
}

void killServer() {
  final settingsController = Get.find<SettingsController>();
  final isKilling = false.obs;

  Get.dialog(
    Obx(() {
      final killing = isKilling.value;
      return AlertDialog(
        title: Text(I18n.areYouSureKill.tr),
        actions: [
          TextButton(
            onPressed: killing
                ? null
                : () {
                    if (Get.isDialogOpen ?? false) {
                      Get.back();
                    }
                  },
            child: Text(I18n.cancel.tr),
          ),
          FilledButton(
            onPressed: killing
                ? null
                : () async {
                    isKilling.value = true;
                    var closedByTimeout = false;
                    final autoCloseTimer = Timer(
                      const Duration(seconds: 5),
                      () {
                        closedByTimeout = true;
                        if (Get.isDialogOpen ?? false) {
                          Get.back();
                        }
                      },
                    );
                    try {
                      final success = await settingsController.killServer();
                      if (success) {
                        if (!closedByTimeout && (Get.isDialogOpen ?? false)) {
                          Get.back();
                        }
                        return;
                      }
                      if (!closedByTimeout) {
                        isKilling.value = false;
                      }
                    } finally {
                      autoCloseTimer.cancel();
                    }
                  },
            child: killing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(I18n.confirm.tr),
          ),
        ],
      );
    }),
    barrierDismissible: false,
  );
}

class AutoScriptDialogContent extends StatelessWidget {
  const AutoScriptDialogContent({super.key});

  @override
  Widget build(BuildContext context) {
    final scriptService = Get.find<ScriptService>();
    final scriptList = scriptService.scriptModelMap.keys.toList()..sort();
    if (scriptList.isEmpty) return Text(I18n.empty.tr);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final name in scriptList)
          Obx(
            () => CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(name),
              value: scriptService.autoScriptList.contains(name),
              onChanged: (selected) =>
                  scriptService.updateAutoScript(name, selected),
            ),
          ),
      ],
    );
  }
}
