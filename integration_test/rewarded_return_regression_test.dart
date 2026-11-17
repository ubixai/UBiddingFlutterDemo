import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'package:ubidding_flutter_example/controllers/ad_page_controller.dart';
import 'package:ubidding_flutter_example/main.dart' as app;

// Real SDK, explicit opt-in, operator closes the native ad (never click content).
// Run separately with complete/skip; record the actual returned source each cycle.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const enabled = bool.fromEnvironment('QA_REWARDED_INTERACTIVE');
  const closeMode = String.fromEnvironment(
    'QA_REWARD_CLOSE_MODE',
    defaultValue: 'complete',
  );
  const cycles = int.fromEnvironment('QA_REWARD_CYCLES', defaultValue: 10);
  final results = <String, Object?>{
    'closeMode': closeMode,
    'cycles': <Object?>[],
  };
  binding.reportData = {'qaResults': results};
  const diagnostics = MethodChannel('ubidding_example/diagnostics');

  Future<Map<String, Object?>> capture() async =>
      await diagnostics.invokeMapMethod<String, Object?>(
        'presentationSnapshot',
      ) ??
      {};

  Future<void> until(
    WidgetTester tester,
    bool Function() ready,
    String reason, {
    int seconds = 60,
  }) async {
    for (var i = 0; i < seconds * 10 && !ready(); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(ready(), true, reason: reason);
  }

  testWidgets(
    'real reward close returns to an interactive home route',
    (tester) async {
      expect(closeMode, isIn(['complete', 'skip']));
      expect(cycles, greaterThan(0));
      app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.text('同意并初始化'));
      await until(
        tester,
        () => find.text('广告类型').evaluate().isNotEmpty,
        'initialize',
      );
      // Remote SDK slot configuration is asynchronous; use the established harness wait.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 10)),
      );
      results['before'] = await capture();
      results['sdkVersion'] = await UBidding.sdkVersion;
      for (var cycle = 0; cycle < cycles; cycle++) {
        await tester.tap(find.text('激励'));
        await tester.pumpAndSettle();
        final host = find.byWidgetPredicate(
          (w) => w is ListenableBuilder && w.listenable is AdPageController,
        );
        final controller =
            tester.widget<ListenableBuilder>(host).listenable
                as AdPageController;
        await tester.tap(find.text('加载'));
        await until(
          tester,
          () => controller.canPresent || controller.phase == AdPagePhase.failed,
          'reward load: ${controller.logs}',
        );
        expect(controller.canPresent, true, reason: controller.logs.join('\n'));
        final info = await controller.ad!.adInfo;
        final events = <Object?>[];
        final sub = controller.ad!.events.listen(
          (e) => events.add({
            'type': e.type,
            'timestamp': e.timestamp,
            'extra': e.extra,
          }),
        );
        final record = <String, Object?>{
          'cycle': cycle + 1,
          'adnId': info?.adnId,
          'adnName': info?.adnName,
          'beforeShow': await capture(),
          'events': events,
        };
        (results['cycles'] as List).add(record);
        try {
          // ignore: avoid_print
          print(
            'QA_REWARD_OPERATOR cycle=${cycle + 1}/$cycles source=${info?.adnName} '
            'mode=$closeMode: close using SDK UI; do not tap ad content.',
          );
          await tester.tap(find.text('展示'));
          await until(
            tester,
            () =>
                controller.phase == AdPagePhase.ended ||
                controller.phase == AdPagePhase.failed,
            'native ad close',
            seconds: 180,
          );
          expect(
            controller.phase,
            AdPagePhase.ended,
            reason: controller.logs.join('\n'),
          );
          await tester.pumpAndSettle();
          record['afterClose'] = await capture();
          // Route interaction asserts Flutter event handling, not physical UIKit touch alone.
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.text('广告类型'), findsOneWidget);
          record['home'] = await capture();
          await tester.drag(find.byType(ListView).first, const Offset(0, -80));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('激励'));
          record['flutterNavigationAndScroll'] = true;
          record['logs'] = List<String>.of(controller.logs);
          if (const bool.fromEnvironment('QA_SCREENSHOTS')) {
            await binding.takeScreenshot(
              'reward_${closeMode}_${cycle + 1}_home',
            );
          }
        } finally {
          await sub.cancel();
        }
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 40)),
  );
}
