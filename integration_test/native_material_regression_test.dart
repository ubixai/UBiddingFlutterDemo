import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'package:ubidding_flutter_example/demo_config.dart';
import 'package:ubidding_flutter_example/pages/native_page.dart';
import 'package:ubidding_flutter_example/widgets/native_layout.dart';

// Real SDK self-render smoke; no ad-content/download clicks or bid reports.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final results = <String, Object?>{};
  binding.reportData = {'qaResults': results};
  testWidgets('real self-render material and privacy-slot mount', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final config = DemoConfig.forPlatform(defaultTargetPlatform);
    final initialized = await UBidding.initialize(
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
    expect(initialized.success, true);
    results['sdkVersion'] = await UBidding.sdkVersion;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 10)),
    );
    if (defaultTargetPlatform == TargetPlatform.android &&
        const bool.fromEnvironment('QA_SCREENSHOTS')) {
      await binding.convertFlutterSurfaceToImage();
    }
    final width = nativeAdWidth(tester.getSize(find.byType(Scaffold)).width)!;
    final ad = UBiddingNativeAd(
      request: UBiddingAdRequest(
        slotId: config.nativeFeedSlotId,
        width: width,
        height: 250,
      ),
    );
    UBiddingAdEvent? terminal;
    final events = <Object?>[];
    final sub = ad.events.listen((e) {
      events.add({
        'type': e.type,
        'adDataId': e.adDataId,
        'extra': e.extra,
        if (e.error != null)
          'error': {'code': e.error!.code, 'details': e.error!.details},
      });
      if (e.adDataId == null &&
          ['loadSuccess', 'loadFailure'].contains(e.type)) {
        terminal = e;
      }
    });
    results['events'] = events;
    try {
      await ad.load();
      for (var i = 0; i < 600 && terminal == null; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(terminal?.type, 'loadSuccess', reason: '$events');
      expect(ad.nativeAdDatas, isNotEmpty);
      final item = ad.nativeAdDatas.firstWhere((item) => !item.isExpress);
      expect(item.expressMaterialType, null);
      final material = (await item.getMaterial())!;
      final info = await ad.getAdInfo(adDataId: item.adDataId);
      results.addAll({
        'adnId': info?.adnId,
        'adnName': info?.adnName,
        'platformExtra': material.platformExtra,
        'ctaText': material.ctaText,
        'requestWidth': width,
      });
      if (defaultTargetPlatform == TargetPlatform.android) {
        expect(material.platformExtra['score'], isA<num>());
        if (material.platformExtra.containsKey('downloadCountText')) {
          expect(material.platformExtra['downloadCountText'], isA<String>());
        }
      }
      final layout = exampleNativeLayout(width, material);
      final choice = layout.slots[UBiddingNativeSlot.choiceView]!;
      final cta = layout.slots[UBiddingNativeSlot.ctaButton]!;
      expect(choice.y + choice.height, lessThanOrEqualTo(cta.y));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: NativeItemCard(item: item),
            ),
          ),
        ),
      );
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find
                .byType(
                  defaultTargetPlatform == TargetPlatform.iOS
                      ? UiKitView
                      : AndroidView,
                )
                .evaluate()
                .isNotEmpty &&
            events.any((e) => (e as Map)['type'] == 'show')) {
          break;
        }
      }
      expect(
        events.any((e) => (e as Map)['type'] == 'show'),
        true,
        reason: '$events',
      );
      expect(
        events.any(
          (e) => ['renderFailure', 'bridgeError'].contains((e as Map)['type']),
        ),
        false,
      );
      expect(find.textContaining('评分（原始）'), findsOneWidget);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        results['presentation'] = await const MethodChannel(
          'ubidding_example/diagnostics',
        ).invokeMapMethod<String, Object?>('presentationSnapshot');
      }
      if (const bool.fromEnvironment('QA_SCREENSHOTS')) {
        await binding.takeScreenshot(
          'native_material_${defaultTargetPlatform.name}',
        );
      }
    } finally {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await sub.cancel();
      await ad.dispose();
    }
  });
}
