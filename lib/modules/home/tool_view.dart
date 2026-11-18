import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:oasx/api/api_client.dart';
import 'package:oasx/translation/i18n_content.dart';

class NotifyTest extends StatefulWidget {
  const NotifyTest({Key? key}) : super(key: key);

  @override
  NotifyTestState createState() => NotifyTestState();
}

class NotifyTestState extends State<NotifyTest> {
  String testConfig = 'provider:';
  String testTitle = 'Title';
  String testContent = 'Content';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _config(),
        const SizedBox(height: 14),
        _title(),
        const SizedBox(height: 14),
        _content(),
        const SizedBox(height: 16),
        _send(),
      ],
    );
  }

  Widget _config() {
    return TextFormField(
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      maxLines: null,
      initialValue: testConfig,
      decoration: InputDecoration(
        labelText: I18n.notifyTestConfig.tr,
        helperMaxLines: 4,
        helperText: I18n.notifyTestHelp.tr,
      ),
      onChanged: (value) {
        setState(() {
          testConfig = value;
        });
      },
    );
  }

  Widget _title() {
    return TextFormField(
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      maxLines: null,
      initialValue: testTitle,
      decoration: InputDecoration(labelText: I18n.notifyTestTitle.tr),
      onChanged: (value) {
        setState(() {
          testTitle = value;
        });
      },
    );
  }

  Widget _content() {
    return TextFormField(
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      maxLines: null,
      initialValue: testContent,
      decoration: InputDecoration(labelText: I18n.notifyTestContent.tr),
      onChanged: (value) {
        setState(() {
          testContent = value;
        });
      },
    );
  }

  Widget _send() {
    return FilledButton(
      onPressed: () {
        ApiClient().notifyTest(testConfig, testTitle, testContent);
      },
      child: Text(I18n.notifyTestSend.tr),
    );
  }
}
