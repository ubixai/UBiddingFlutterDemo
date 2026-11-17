import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'package:ubidding_flutter_example/demo_config.dart';
import 'package:ubidding_flutter_example/main.dart' as app;
import 'package:ubidding_flutter_example/pages/native_page.dart';
import 'package:ubidding_flutter_example/widgets/native_layout.dart';
import 'package:ubidding_flutter_example/controllers/ad_page_controller.dart';

// Real SDK/network. Bounded requests; no bid reports, ad-content automation,
// source filtering, synthetic SDK callbacks or automatic initialization retries.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  // Manual SDK controls must reach Flutter's platform-view gesture routing.
  // Otherwise TestWidgetsFlutterBinding consumes real touches as finder probes.
  binding.shouldPropagateDevicePointerEvents = true;
  final config = DemoConfig.forPlatform(defaultTargetPlatform);
  final results = <String, Object?>{'platform': defaultTargetPlatform.name};
  binding.reportData = {'qaResults': results};
  var initialized = false;
  const screenshots = bool.fromEnvironment('QA_SCREENSHOTS');
  const nativeClose = bool.fromEnvironment('QA_NATIVE_CLOSE_INTERACTIVE');
  const bannerClick = bool.fromEnvironment('QA_BANNER_CLICK_INTERACTIVE');
  const rewarded = bool.fromEnvironment('QA_REWARDED_INTERACTIVE');
  const only = String.fromEnvironment('QA_ONLY');
  const nativeRequestHeight = int.fromEnvironment(
    'QA_NATIVE_REQUEST_HEIGHT',
    defaultValue: 344,
  );

  Future<void> until(
    WidgetTester tester,
    bool Function() ready,
    String reason, {
    int seconds = 60,
  }) async {
    for (var n = 0; n < seconds * 10 && !ready(); n++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(ready(), true, reason: reason);
  }

  Future<Object?> snapshot() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return null;
    return const MethodChannel(
      'ubidding_example/diagnostics',
    ).invokeMapMethod<String, Object?>('presentationSnapshot');
  }

  List<Map<String, Object?>> closeHits(Object? value) {
    final hits = <Map<String, Object?>>[];
    void visit(Object? node) {
      if (node is Map) {
        if (node['sdkCloseSlot'] == true || node['sdkCloseSlot'] == 1) {
          hits.add({
            for (final key in [
              'class',
              'rectInWindow',
              'gestureCount',
              'interactionEnabled',
              'windowHitClass',
              'windowHitIsClose',
            ])
              key: node[key],
          });
        }
        for (final child in node.values) {
          visit(child);
        }
      } else if (node is List) {
        for (final child in node) {
          visit(child);
        }
      }
    }

    visit(value);
    return hits;
  }

  Future<void> screenshot(String name) async {
    if (screenshots) {
      await binding.takeScreenshot(
        'pending_${defaultTargetPlatform.name}_$name',
      );
    }
  }

  Map<String, Object?> event(UBiddingAdEvent e) => {
    'type': e.type,
    'source': e.source,
    'timestamp': e.timestamp,
    if (e.adDataId != null) 'adDataId': e.adDataId,
    if (e.extra['width'] != null) 'width': e.extra['width'],
    if (e.extra['height'] != null) 'height': e.extra['height'],
    if (e.error != null)
      'error': {
        'code': e.error!.code,
        'message': e.error!.message,
        'domain': e.error!.domain,
        'nativeCode': e.error!.details is Map
            ? (e.error!.details as Map)['nativeCode']
            : null,
      },
  };

  testWidgets(
    'real initialization and explicit repeated call',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('真机缺陷验证'))),
      );
      final configuration = UBiddingConfig(
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
      );
      final first = await UBidding.initialize(configuration);
      expect(first.success, true);
      final second = await UBidding.initialize(configuration);
      expect(second.success, true);
      initialized = true;
      results['initialization'] = {
        'first': first.success,
        'explicitSecond': second.success,
        'sdkVersion': await UBidding.sdkVersion,
      };
      if (screenshots && defaultTargetPlatform == TargetPlatform.android) {
        await binding.convertFlutterSurfaceToImage();
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 10)),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'real banner geometry and SDK callbacks',
    (tester) async {
      expect(initialized, true);
      final record = <String, Object?>{};
      results['banner'] = record;
      final ad = UBiddingBannerAd(
        request: UBiddingAdRequest(
          slotId: config.bannerSlotId,
          width: 320,
          height: 50,
        ),
      );
      final events = <Map<String, Object?>>[];
      record['events'] = events;
      final sub = ad.events.listen((e) {
        events.add(event(e));
        // ignore: avoid_print
        print('QA_PENDING_BANNER ${jsonEncode(event(e))}');
      });
      try {
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        await ad.load();
        await until(
          tester,
          () => events.any(
            (e) => ['loadSuccess', 'loadFailure'].contains(e['type']),
          ),
          'banner SDK load',
        );
        expect(
          events.any((e) => e['type'] == 'loadSuccess'),
          true,
          reason: '$events',
        );
        final info = await ad.adInfo;
        record.addAll({
          'adnName': info?.adnName,
          'adnId': info?.adnId,
          'requestWidth': ad.request.width,
          'requestHeight': ad.request.height,
        });
        // Same height policy as the production example BannerPage.
        Widget bannerHost() => MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Banner 真机验证')),
            body: Column(
              children: [
                const Text('仅人工测试点击，随后返回此页'),
                StreamBuilder<UBiddingAdEvent>(
                  stream: ad.events,
                  builder: (_, _) =>
                      ad.buildView(height: ad.renderSize?.height),
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(bannerHost());
        await until(
          tester,
          () => events.any(
            (e) => ['show', 'showFailure', 'bridgeError'].contains(e['type']),
          ),
          'banner native show',
        );
        expect(events.any((e) => e['type'] == 'show'), true, reason: '$events');
        final platform = find.byType(
          defaultTargetPlatform == TargetPlatform.iOS ? UiKitView : AndroidView,
        );
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          await until(
            tester,
            () => ad.renderSize != null,
            'actual banner material geometry',
            seconds: 15,
          );
        }
        await tester.pump(const Duration(seconds: 1));
        final state = tester.state(platform);
        final size = tester.getSize(platform);
        record.addAll({
          'actualWidth': ad.renderSize?.width,
          'actualHeight': ad.renderSize?.height,
          'displayWidth': size.width,
          'displayHeight': size.height,
          'native': await snapshot(),
        });
        expect(size.width, 320);
        if (ad.renderSize != null) {
          expect(size.height, closeTo(ad.renderSize!.height, 1));
        }
        await screenshot('banner_geometry');
        if (bannerClick) {
          // ignore: avoid_print
          print(
            'QA_PENDING_OPERATOR BANNER: manually tap the TEST banner once, then close the SDK landing page; never download/install.',
          );
          await until(
            tester,
            () => events.any((e) => e['type'] == 'click'),
            'operator banner click / real SDK click',
            seconds: 90,
          );
          record['sdkClickReceived'] = true;
          await until(
            tester,
            () => events.any((e) => e['type'] == 'detailClosed'),
            'SDK detail page return',
            seconds: 60,
          );
        }
        await tester.pumpWidget(bannerHost());
        await tester.pump(const Duration(milliseconds: 300));
        record['samePlatformViewAfterHostRebuild'] = identical(
          state,
          tester.state(platform),
        );
        expect(record['samePlatformViewAfterHostRebuild'], true);
        record['passed'] = true;
      } finally {
        record['finalNative'] = await snapshot();
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        await sub.cancel();
        await ad.dispose();
      }
    },
    skip: only.isNotEmpty && only != 'banner',
    timeout: const Timeout(Duration(minutes: 5)),
  );

  testWidgets(
    'real self-render SDK-owned close',
    (tester) async {
      expect(initialized, true);
      final record = <String, Object?>{};
      results['nativeClose'] = record;
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final width = nativeAdWidth(tester.getSize(find.byType(Scaffold)).width)!;
      final ad = UBiddingNativeAd(
        request: UBiddingAdRequest(
          slotId: config.nativeFeedSlotId,
          width: width,
          height: nativeRequestHeight.toDouble(),
        ),
      );
      final events = <Map<String, Object?>>[];
      record['events'] = events;
      final sub = ad.events.listen((e) {
        events.add(event(e));
        // ignore: avoid_print
        print('QA_PENDING_NATIVE ${jsonEncode(event(e))}');
      });
      try {
        await ad.load();
        await until(
          tester,
          () => events.any(
            (e) => ['loadSuccess', 'loadFailure'].contains(e['type']),
          ),
          'native SDK load',
        );
        expect(ad.nativeAdDatas, isNotEmpty, reason: '$events');
        final item = ad.nativeAdDatas.firstWhere((i) => !i.isExpress);
        final info = await ad.getAdInfo(adDataId: item.adDataId);
        record.addAll({
          'adnName': info?.adnName,
          'adnId': info?.adnId,
          'adDataId': item.adDataId,
          'requestHeight': ad.request.height,
          'layoutHeight': exampleNativeAdHeight,
        });
        // ignore: avoid_print
        print(
          'QA_PENDING_NATIVE_INFO ${jsonEncode({'adnName': info?.adnName, 'adnId': info?.adnId, 'adDataId': item.adDataId})}',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: const Text('原生关闭验证')),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(child: NativeItemCard(item: item)),
              ),
            ),
          ),
        );
        await until(
          tester,
          () => events.any(
            (e) => e['type'] == 'show' && e['adDataId'] == item.adDataId,
          ),
          'native SDK show',
        );
        record['beforeClose'] = await snapshot();
        final platform = find.byType(
          defaultTargetPlatform == TargetPlatform.iOS ? UiKitView : AndroidView,
        );
        expect(tester.getSize(platform).height, exampleNativeAdHeight);
        // Host controls only: keep the SDK object and verify a fresh platform mount.
        await tester.ensureVisible(find.text('解绑此条'));
        await tester.tap(find.text('解绑此条'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(platform, findsNothing);
        await tester.tap(find.text('重挂载此条'));
        await tester.pump(const Duration(seconds: 1));
        expect(platform, findsOneWidget);
        expect(tester.getSize(platform).height, exampleNativeAdHeight);
        record['afterRemount'] = await snapshot();
        record['hostDetachRemount'] = true;
        record['closeHits'] = closeHits(record['afterRemount']);
        // ignore: avoid_print
        print(
          'QA_PENDING_NATIVE_GEOMETRY ${jsonEncode({'requestHeight': ad.request.height, 'layoutHeight': exampleNativeAdHeight, 'closeHits': record['closeHits']})}',
        );
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          final hits = record['closeHits'] as List<Map<String, Object?>>;
          expect(hits, isNotEmpty);
          expect(hits.every((hit) => hit['windowHitIsClose'] == true), true);
        }
        await screenshot('native_before_close');
        if (nativeClose) {
          // ignore: avoid_print
          print(
            'QA_PENDING_OPERATOR NATIVE: tap SDK close icon at the top right of the ad; do not tap content.',
          );
          await until(
            tester,
            () => events.any(
              (e) => e['type'] == 'dismiss' && e['adDataId'] == item.adDataId,
            ),
            'operator native close / SDK dismiss',
            seconds: 180,
          );
          await tester.pump(const Duration(milliseconds: 300));
          record['afterClose'] = await snapshot();
          record['sdkDismissReceived'] = true;
          expect(item.hasLoaded, false);
          await screenshot('native_after_close');
        }
        record['passed'] = true;
      } finally {
        record['finalNative'] = await snapshot();
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        await sub.cancel();
        await ad.dispose();
      }
    },
    skip: only.isNotEmpty && only != 'native',
    timeout: const Timeout(Duration(minutes: 5)),
  );

  testWidgets(
    'real reward closes and home route remains interactive',
    (tester) async {
      expect(initialized, true);
      final record = <String, Object?>{};
      results['rewardReturn'] = record;
      app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.text('同意并初始化'));
      await until(
        tester,
        () => find.text('广告类型').evaluate().isNotEmpty,
        'example initialize',
      );
      await tester.tap(find.text('激励'));
      await tester.pumpAndSettle();
      final host = find.byWidgetPredicate(
        (w) => w is ListenableBuilder && w.listenable is AdPageController,
      );
      final controller =
          tester.widget<ListenableBuilder>(host).listenable as AdPageController;
      await tester.tap(find.text('加载'));
      await until(
        tester,
        () => controller.canPresent || controller.phase == AdPagePhase.failed,
        'reward SDK load',
      );
      record['loadLogs'] = List<String>.of(controller.logs);
      expect(controller.canPresent, true, reason: controller.logs.join('\n'));
      final info = await controller.ad!.adInfo;
      final events = <Map<String, Object?>>[];
      record.addAll({
        'adnName': info?.adnName,
        'adnId': info?.adnId,
        'events': events,
        'beforeShow': await snapshot(),
      });
      final sub = controller.ad!.events.listen((e) {
        events.add(event(e));
        // ignore: avoid_print
        print('QA_PENDING_REWARD ${jsonEncode(event(e))}');
      });
      try {
        // ignore: avoid_print
        print(
          'QA_PENDING_OPERATOR REWARD: watch then close/skip using SDK controls; do not tap content.',
        );
        await tester.tap(find.text('展示'));
        await until(
          tester,
          () =>
              controller.phase == AdPagePhase.ended ||
              controller.phase == AdPagePhase.failed,
          'operator reward close',
          seconds: 180,
        );
        record['afterClose'] = await snapshot();
        record['logs'] = List<String>.of(controller.logs);
        expect(controller.phase, AdPagePhase.ended);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('广告类型'), findsOneWidget);
        await tester.drag(find.byType(ListView).first, const Offset(0, -80));
        await tester.pumpAndSettle();
        record['home'] = await snapshot();
        record['flutterNavigationAndScroll'] = true;
        await screenshot('reward_home');
        record['passed'] = true;
      } finally {
        await sub.cancel();
      }
    },
    skip: !rewarded || (only.isNotEmpty && only != 'reward'),
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
