import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'package:ubidding_flutter_example/demo_config.dart';
import 'package:ubidding_flutter_example/pages/ad_page.dart';
import 'package:ubidding_flutter_example/pages/native_page.dart';
import 'package:ubidding_flutter_example/pages/splash_page.dart';
import 'package:ubidding_flutter_example/widgets/native_video_controls.dart';

// Real SDK checks. UI controls only: no ad-content clicks or bidding reports.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final results = <String, Object?>{};
  binding.reportData = {'qaResults': results};
  final config = DemoConfig.forPlatform(defaultTargetPlatform);
  Map<String, Object?> record(UBiddingAdEvent e) => {
    'type': e.type,
    'extra': e.extra,
    if (e.error != null)
      'error': {
        'code': e.error!.code,
        'message': e.error!.message,
        'domain': e.error!.domain,
        'details': e.error!.details,
      },
  };
  Future<void> until(
    WidgetTester tester,
    bool Function() ready,
    String reason, {
    int seconds = 40,
  }) async {
    for (var i = 0; i < seconds * 10 && !ready(); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(ready(), true, reason: reason);
  }

  Future<void> screenshot(String stage) async {
    if (const bool.fromEnvironment('QA_SCREENSHOTS')) {
      await binding.takeScreenshot(stage);
    }
  }

  testWidgets('real SDK initialization', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final result = await UBidding.initialize(
      UBiddingConfig(
        appId: config.appId,
        sensorEnabled: false,
        privacy: const UBiddingPrivacyConfig(
          canUseLocation: false,
          canReadInstalledPackages: false,
          canUsePhoneState: false,
          canUseWifiState: false,
          canWriteExternalStorage: false,
          canUseOaid: false,
          canUseAndroidId: false,
          canUseMacAddress: false,
          canReadIdfa: false,
          canReadNetworkType: false,
          personalizedAds: false,
          programmaticRecommendation: false,
        ),
      ),
    );
    expect(result.success, true);
    results['sdkVersion'] = await UBidding.sdkVersion;
    expect(
      results['sdkVersion'],
      defaultTargetPlatform == TargetPlatform.iOS ? '4.1.2.13' : '4.1.2.11',
    );
    if (defaultTargetPlatform == TargetPlatform.android &&
        const bool.fromEnvironment('QA_SCREENSHOTS')) {
      await binding.convertFlutterSurfaceToImage();
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 10)),
    );
  });
  testWidgets('self-render video controls invoke real per-item SDK commands', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final width = nativeAdWidth(tester.getSize(find.byType(Scaffold)).width)!;
    final ad = UBiddingNativeAd(
      request: UBiddingAdRequest(
        slotId: config.nativeFeedSlotId,
        width: width,
        height: 250,
      ),
    );
    final events = <Map<String, Object?>>[];
    UBiddingAdEvent? terminal;
    final sub = ad.events.listen((e) {
      events.add(record(e));
      if (e.type == 'loadSuccess' || e.type == 'loadFailure') terminal = e;
    });
    final detail = <String, Object?>{
      'events': events,
      'commands': <String>[],
      'requestWidth': width,
    };
    results['nativeVideo'] = detail;
    try {
      await ad.load();
      await until(
        tester,
        () => terminal != null,
        'Real native load must return a terminal event',
      );
      expect(
        terminal!.type,
        'loadSuccess',
        reason: '${terminal!.error?.message} ${terminal!.error?.details}',
      );
      final offers = ad.nativeAdDatas.where((i) => !i.isExpress);
      expect(
        offers,
        isNotEmpty,
        reason: 'Self-render offer required, not a template substitute',
      );
      final item = offers.first;
      detail['adDataId'] = item.adDataId;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: NativeItemCard(item: item),
            ),
          ),
        ),
      );
      await until(
        tester,
        () =>
            find.byType(NativeVideoControls).evaluate().isNotEmpty ||
            find.textContaining('调用异常').evaluate().isNotEmpty,
        'Real offer must contain video material to validate video controls',
        seconds: 10,
      );
      expect(find.byType(NativeVideoControls), findsOneWidget);
      await until(
        tester,
        () => events.any(
          (e) => e['type'] == 'renderSuccess' || e['type'] == 'show',
        ),
        'Native view must really render/show',
        seconds: 15,
      );
      await screenshot('native_video_controls');
      for (final command in NativeVideoCommand.values) {
        final button = find.byKey(ValueKey('native-video-${command.name}'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        await until(
          tester,
          () => tester.widget<TextButton>(button).onPressed != null,
          'Video command must finish',
          seconds: 5,
        );
        expect(
          find.textContaining('${command.label}调用已返回（ACK）'),
          findsOneWidget,
        );
        (detail['commands'] as List<String>).add(command.name);
      }
      detail['commandAckPassed'] = true;
      detail['playbackAcceptance'] =
          'ACKs and raw SDK events only; screenshots do not prove playback or audio';
    } finally {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump(const Duration(milliseconds: 300));
      await ad.dispose();
      await sub.cancel();
    }
  });
  testWidgets(
    'splash early finalization and bottom enabled real presentation',
    (tester) async {
      final source = SplashPage();
      UBiddingSplashAd? ad;
      StreamSubscription<UBiddingAdEvent>? sub;
      UBiddingAdEvent? terminal;
      final events = <Map<String, Object?>>[];
      final detail = <String, Object?>{
        'events': events,
        'finalizeTapped': false,
      };
      results['splash'] = detail;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: AdPage(
              label: source.label,
              slot: source.slot,
              isSplash: true,
              createAd: (s) {
                ad = source.createAd(s) as UBiddingSplashAd;
                sub = ad!.events.listen((e) {
                  events.add(record(e));
                  if (e.type == 'loadSuccess' || e.type == 'loadFailure') {
                    terminal = e;
                  }
                });
                return ad!;
              },
            ),
          ),
        );
        await tester.pump();
        final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
        expect(tile.value, false);
        await tester.tap(find.byType(Switch));
        await tester.pump();
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          true,
        );
        await tester.tap(find.widgetWithText(ElevatedButton, '加载'));
        final finish = find.widgetWithText(ElevatedButton, '提前结束竞价');
        await until(
          tester,
          () =>
              terminal != null ||
              tester.widget<ElevatedButton>(finish).onPressed != null,
          'Loading ACK or terminal must arrive',
        );
        if (terminal == null) {
          await tester.tap(finish);
          detail['finalizeTapped'] = true;
        }
        await until(
          tester,
          () => terminal != null,
          'Real finalize/load must return a terminal event',
        );
        await tester.tap(find.text('诊断'));
        await tester.pump();
        detail['logs'] = tester
            .widgetList<SelectableText>(find.byType(SelectableText))
            .map((t) => t.data)
            .toList();
        expect(
          terminal!.type,
          'loadSuccess',
          reason: '${terminal!.error?.message} ${terminal!.error?.details}',
        );
        await tester.ensureVisible(find.widgetWithText(ElevatedButton, '展示'));
        await tester.tap(find.widgetWithText(ElevatedButton, '展示'));
        await until(
          tester,
          () => events.any(
            (e) => e['type'] == 'show' || e['type'] == 'showFailure',
          ),
          'Real show callback required',
        );
        expect(events.any((e) => e['type'] == 'show'), true);
        await tester.pump(const Duration(milliseconds: 500));
        await screenshot('splash_bottom_enabled');
        detail['showPassed'] = true;
        await until(
          tester,
          () => events.any((e) => e['type'] == 'dismiss'),
          'Splash must close and return to host',
          seconds: 30,
        );
        expect(find.widgetWithText(ElevatedButton, '加载'), findsOneWidget);
        detail['dismissPassed'] = true;
      } finally {
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        await tester.pump(const Duration(milliseconds: 300));
        await ad?.dispose();
        await sub?.cancel();
      }
    },
  );
}
