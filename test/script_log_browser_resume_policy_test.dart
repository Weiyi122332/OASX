import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/modules/log/script_log_browser_controller.dart';

void main() {
  test('log browser wraps lines by default', () {
    final controller = ScriptLogBrowserController(scriptName: 'demo');

    expect(controller.wrapLines.value, isTrue);
  });

  test('auto-scroll info view marks latest refresh on hide', () {
    final controller = ScriptLogBrowserController(scriptName: 'demo');

    controller.handleInfoViewHidden();

    expect(controller.shouldRefreshLatestOnInfoResume, isTrue);
  });

  test('manual info view keeps current restore policy on hide', () {
    final controller = ScriptLogBrowserController(scriptName: 'demo');
    controller.autoScroll.value = false;

    controller.handleInfoViewHidden();

    expect(controller.shouldRefreshLatestOnInfoResume, isFalse);
  });
}
