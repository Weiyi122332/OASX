import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:oasx/service/illustration_service.dart';

class IllustrationSettingsCard extends StatefulWidget {
  const IllustrationSettingsCard({super.key, this.service});
  final IllustrationService? service;
  @override
  State<IllustrationSettingsCard> createState() =>
      _IllustrationSettingsCardState();
}

class _IllustrationSettingsCardState extends State<IllustrationSettingsCard> {
  late final IllustrationService _service =
      widget.service ?? Get.find<IllustrationService>();
  late final TextEditingController _interval = TextEditingController(
    text: '${_service.intervalSeconds.value}',
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  void _saveInterval() {
    if (!_formKey.currentState!.validate()) return;
    _service.setInterval(int.parse(_interval.text));
  }

  @override
  Widget build(BuildContext context) => Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '插画设置',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用插画背景'),
              value: _service.enabled.value,
              onChanged: _service.setEnabled,
            ),
            Text('插画透明度：${_service.transparency.value}%'),
            Slider(
              value: _service.transparency.value.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              label: '${_service.transparency.value}%',
              onChanged: (value) => _service.setTransparency(value.round()),
            ),
            const Text('0% 为不透明，100% 为完全透明。', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: SizedBox(
                width: 260,
                child: TextFormField(
                  key: const ValueKey('illustration-interval'),
                  controller: _interval,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '切换速度',
                    suffixText: '秒',
                    helperText: '整数，10–60 秒；默认 15 秒',
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    final n = int.tryParse(value ?? '');
                    return n == null || n < 10 || n > 60
                        ? '请输入 10–60 的整数'
                        : null;
                  },
                  onChanged: (_) {
                    final n = int.tryParse(_interval.text);
                    if (n != null && n >= 10 && n <= 60) {
                      _service.setInterval(n);
                    }
                  },
                  onFieldSubmitted: (_) => _saveInterval(),
                  onTapOutside: (_) {
                    _saveInterval();
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _service.pictures.isEmpty
                  ? '暂无插画，当前不启用背景或轮播。'
                  : '本次启动已读取 ${_service.pictures.length} 张插画。',
            ),
            if (_service.directoryPath.value.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                _service.directoryPath.value,
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (_service.loadError.value.isNotEmpty)
              Text(
                _service.loadError.value,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            const Text(
              '将 JPG、JPEG、PNG 图片放入程序目录下的 pictures 文件夹。\n新增、替换或删除插画后，请重启 OASX 更新图片列表。',
            ),
          ],
        ),
      ),
    ),
  );
}
