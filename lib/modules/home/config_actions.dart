import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:oasx/modules/common/widgets/workbench_dialog.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/api/config_transfer_models.dart';
import 'package:oasx/service/script_service.dart';
import 'package:oasx/translation/i18n_content.dart';
import 'package:oasx/utils/browser_download_io.dart'
    if (dart.library.html) 'package:oasx/utils/browser_download_web.dart';
import 'package:oasx/utils/file_save_stub.dart'
    if (dart.library.io) 'package:oasx/utils/file_save_io.dart';

class ConfigActions {
  const ConfigActions._();

  static String? validateRenameName({
    required String oldName,
    required String newName,
    required ScriptService scriptService,
  }) {
    if (newName.isEmpty) {
      return I18n.nameCannotEmpty.tr;
    }
    if (['Home', 'home'].contains(newName)) {
      return I18n.nameInvalid.tr;
    }
    if (oldName == newName || scriptService.scriptOrderList.contains(newName)) {
      return I18n.nameDuplicate.tr;
    }
    return null;
  }

  static Future<bool> renameScript({
    required ScriptService scriptService,
    required String oldName,
    required String newName,
  }) async {
    final canRename = await scriptService.tryCloseScriptWithReason(oldName);
    if (!canRename) return false;

    final success = await scriptService.renameConfig(oldName, newName);
    if (!success) {
      Get.snackbar(I18n.error.tr, '');
    }
    return success;
  }

  static Future<String?> showRenameDialog({
    required ScriptService scriptService,
    required String oldName,
  }) async {
    var newName = oldName;
    final formKey = GlobalKey<FormState>();
    var submitting = false;
    final result = await Get.dialog<String>(
      StatefulBuilder(
        builder: (context, setDialogState) => WorkbenchDialog(
          title: I18n.rename.tr,
          content: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: TextFormField(
              initialValue: oldName,
              enabled: !submitting,
              decoration: InputDecoration(labelText: I18n.newName.tr),
              validator: (value) => validateRenameName(
                oldName: oldName,
                newName: value?.trim() ?? '',
                scriptService: scriptService,
              ),
              onChanged: (value) => newName = value.trim(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(context).pop(),
              child: Text(I18n.cancel.tr),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => submitting = true);
                      try {
                        final renamed = await renameScript(
                          scriptService: scriptService,
                          oldName: oldName,
                          newName: newName,
                        );
                        if (renamed &&
                            context.mounted &&
                            ModalRoute.of(context)?.isCurrent == true) {
                          Navigator.of(context).pop(newName);
                        }
                      } finally {
                        if (context.mounted) {
                          setDialogState(() => submitting = false);
                        }
                      }
                    },
              child: Text(I18n.confirm.tr),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  static Future<void> showDeleteDialog({
    required ScriptService scriptService,
    required String name,
  }) async {
    final canDelete = await scriptService.tryCloseScriptWithReason(name);
    if (!canDelete) return;

    final confirmed = await Get.dialog<bool>(
      Builder(
        builder: (context) => WorkbenchDialog(
          title: I18n.delete.tr,
          content: Text('${I18n.deleteConfirm.tr} "$name"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(I18n.cancel.tr),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(I18n.delete.tr),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final success = await scriptService.deleteConfig(name);
    if (!success) Get.snackbar(I18n.error.tr, '');
  }

  static Future<void> exportScript({required String name}) async {
    try {
      final payload = await ApiClient().exportConfig(name);
      if (kIsWeb) {
        await downloadBytesToBrowser(
          payload.bytes,
          payload.fileName,
          mimeType: 'application/json',
        );
        Get.snackbar(I18n.tip.tr, I18n.configExportSuccess.tr);
        return;
      }
      final path = await FilePicker.platform.saveFile(
        fileName: payload.fileName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: payload.bytes,
      );
      if (path == null || path.trim().isEmpty) {
        return;
      }
      if (shouldWritePickedSavePath()) {
        await saveBytesToPath(path, payload.bytes);
      }
      Get.snackbar(I18n.tip.tr, I18n.configExportSuccess.tr);
    } catch (e) {
      final message = e is ConfigTransferException
          ? e.message
          : I18n.configExportFailed.tr;
      Get.snackbar(I18n.tip.tr, message);
    }
  }
}
