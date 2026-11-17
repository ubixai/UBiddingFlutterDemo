import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'package:ubidding_flutter_example/widgets/native_layout.dart';

import 'package:ubidding_flutter_example/demo_config.dart';

// Real SDK/network checks: load failures are failures, not synthetic passes.
// This suite does not click ads or send artificial bidding reports.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final config = DemoConfig.forPlatform(defaultTargetPlatform);

  final expectedSdkVersion = defaultTargetPlatform == TargetPlatform.iOS
      ? '4.1.2.13'
      : '4.1.2.11';

  testWidgets(
    'SDK $expectedSdkVersion initialization and repeated initialization',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                '适配器真机测试进行中\n正在等待 SDK 回调',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
      await UBidding.initialize(
        UBiddingConfig(appId: config.appId, debugLogEnabled: true),
      );
      expect(await UBidding.isInitialized, isTrue);
      final version = await UBidding.sdkVersion;
      debugPrint('QA_REGRESSION SDK_VERSION=$version');
      expect(version, expectedSdkVersion);
      // Allow asynchronous remote slot configuration to arrive before load probes.
      await tester.pump(const Duration(seconds: 10));
      await UBidding.initialize(
        UBiddingConfig(appId: config.appId, debugLogEnabled: true),
      );
      expect(await UBidding.isInitialized, isTrue);
    },
  );

  final slots = <String, (UBiddingAdType, String)>{
    'splash': (UBiddingAdType.splash, config.splashSlotId),
    'interstitial': (UBiddingAdType.interstitial, config.interstitialSlotId),
    'rewarded': (UBiddingAdType.rewarded, config.rewardedSlotId),
    'templateFeed': (UBiddingAdType.native, config.templateFeedSlotId),
    'nativeFeed': (UBiddingAdType.native, config.nativeFeedSlotId),
    'banner': (UBiddingAdType.banner, config.bannerSlotId),
  };
  for (final entry in slots.entries) {
    testWidgets('${entry.key}: load, ready, metadata, mount, dispose', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                '适配器真机测试进行中\n正在等待 SDK 回调',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
      await UBidding.initialize(
        UBiddingConfig(appId: config.appId, debugLogEnabled: true),
      );
      final request = UBiddingAdRequest(
        slotId: entry.value.$2,
        width: 320,
        height: entry.value.$1 == UBiddingAdType.banner ? 50 : 250,
      );
      final UBiddingAd ad = switch (entry.value.$1) {
        UBiddingAdType.splash => UBiddingSplashAd(request: request),
        UBiddingAdType.interstitial => UBiddingInterstitialAd(request: request),
        UBiddingAdType.rewarded => UBiddingRewardedAd(request: request),
        UBiddingAdType.native => UBiddingNativeAd(request: request),
        UBiddingAdType.banner => UBiddingBannerAd(request: request),
      };
      final terminal = Completer<UBiddingAdEvent>();
      final events = <String>[];
      final subscription = ad.events.listen((event) {
        events.add(event.type);
        debugPrint(
          'QA_REGRESSION ${entry.key} EVENT ${jsonEncode({
            'type': event.type,
            'error': event.error == null ? null : {'code': event.error!.code, 'message': event.error!.message, 'domain': event.error!.domain, 'details': event.error!.details},
            'extra': event.extra,
          })}',
        );
        expectSync(event.requestId, ad.requestId);
        expectSync(event.slotId, request.slotId);
        if ((event.type == 'loadSuccess' || event.type == 'loadFailure') &&
            !terminal.isCompleted) {
          terminal.complete(event);
        }
      });
      try {
        expect(await ad.isReady(), isFalse);
        await ad.load();
        final result = await terminal.future.timeout(
          const Duration(seconds: 25),
        );
        expect(
          result.type,
          'loadSuccess',
          reason:
              '${result.error?.code}: ${result.error?.message} ${result.error?.details}',
        );
        expect(await ad.isReady(), isTrue);
        final info = ad is UBiddingNativeAd && ad.nativeAdDatas.isNotEmpty
            ? await ad.getAdInfo(adDataId: ad.nativeAdDatas.first.adDataId)
            : await ad.adInfo;
        debugPrint(
          'QA_REGRESSION ${entry.key} INFO ${jsonEncode({'ecpm': info?.ecpm, 'adnName': info?.adnName, 'extra': info?.extra})}',
        );
        expect(info, isNotNull);
        if (ad is UBiddingEmbeddedAd || ad is UBiddingNativeAd) {
          final handles = <UBiddingAdViewHandle>[
            if (ad is UBiddingEmbeddedAd) ad,
            if (ad is UBiddingNativeAd) ...ad.nativeAdDatas,
          ];
          final views = <Widget>[];
          for (final item in handles) {
            final material = item is UBiddingNativeAdData
                ? await item.getMaterial()
                : null;
            views.add(
              item.buildView(
                key: ValueKey(item.adDataId ?? item.requestId),
                nativeLayout: material == null
                    ? null
                    : exampleNativeLayout(320, material),
              ),
            );
          }
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(child: Column(children: views)),
              ),
            ),
          );
          for (var frame = 0; frame < 50; frame++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(events, isNot(contains('renderFailure')));
          expect(events, isNot(contains('bridgeError')));
          expect(
            events.any((type) => type == 'show' || type == 'renderSuccess'),
            isTrue,
            reason: 'Embedded ad must emit a successful render/show callback',
          );
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Text(
                    '适配器真机测试进行中\n正在等待 SDK 回调',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
        }
      } finally {
        await ad.dispose();
        await ad.dispose();
        expect(ad.isDisposed, isTrue);
        await expectLater(
          ad.isReady(),
          throwsA(isA<UBiddingAdDisposedException>()),
        );
        await subscription.cancel();
        debugPrint('QA_REGRESSION ${entry.key} DISPOSE_OK');
      }
    });
  }
}
