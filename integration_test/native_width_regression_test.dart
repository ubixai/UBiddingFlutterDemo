import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'package:ubidding_flutter_example/demo_config.dart';
import 'package:ubidding_flutter_example/pages/native_page.dart';

// Real SDK template rendering only. No ad clicks or artificial bid notifications.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final results = <String, Object?>{};
  binding.reportData = {'qaResults': results};
  testWidgets('measured template width and manual resize reload on device', (
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
    if (defaultTargetPlatform == TargetPlatform.android &&
        const bool.fromEnvironment('QA_SCREENSHOTS')) {
      await binding.convertFlutterSurfaceToImage();
    }
    // SDK remote slot configuration is asynchronous; match the existing device harness.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 10)),
    );
    final viewport = ValueNotifier<double?>(null);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<double?>(
          valueListenable: viewport,
          builder: (_, width, _) => Align(
            child: SizedBox(
              width: width,
              child: const NativePage(key: ValueKey('native-page')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final originalHostWidth = tester.getSize(find.byType(NativePage)).width;
    Future<void> captureFailure(String stage) async {
      final evidence = <String, Object?>{
        'text': tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data)
            .whereType<String>()
            .toList(),
        'items': tester
            .widgetList<NativeItemCard>(find.byType(NativeItemCard))
            .map(
              (card) => <String, Object?>{
                'adDataId': card.item.adDataId,
                'requestWidth': card.item.request.width,
                'isExpress': card.item.isExpress,
                'state': card.item.state.name,
                'renderSize': card.item.renderSize?.toString(),
              },
            )
            .toList(),
      };
      results['failure_$stage'] = evidence;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        evidence['nativePresentation'] = await const MethodChannel(
          'ubidding_example/diagnostics',
        ).invokeMapMethod<String, Object?>('presentationSnapshot');
      }
      if (const bool.fromEnvironment('QA_SCREENSHOTS')) {
        await binding.takeScreenshot('native_width_failure_$stage');
      }
    }

    Future<NativeItemCard> waitForTemplate(String stage) async {
      for (var frame = 0; frame < 600; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.textContaining('loadFailure').evaluate().isNotEmpty ||
            find.textContaining('bridgeError').evaluate().isNotEmpty) {
          await captureFailure(stage);
          fail('Real SDK failed during $stage: ${results['failure_$stage']}');
        }
        final cards = tester.widgetList<NativeItemCard>(
          find.byType(NativeItemCard),
        );
        if (cards.isNotEmpty && cards.first.item.renderSize != null) {
          return cards.first;
        }
      }
      await captureFailure(stage);
      fail('No real template renderSize during $stage');
    }

    Future<void> verify(
      NativeItemCard card,
      double hostWidth,
      String stage,
    ) async {
      final item = card.item;
      results[stage] = <String, Object?>{
        'adDataId': item.adDataId,
        'hostWidth': hostWidth,
        'requestWidth': item.request.width,
        'renderWidth': item.renderSize!.width,
        'renderHeight': item.renderSize!.height,
        'expressMaterialType': item.expressMaterialType,
      };
      if (const bool.fromEnvironment('QA_SCREENSHOTS')) {
        await binding.takeScreenshot(stage);
      }
      expect(item.isExpress, true);
      final expected = nativeAdWidth(hostWidth)!;
      expect(item.request.width, expected);
      expect(item.renderSize!.width, lessThanOrEqualTo(expected + 1));
      expect(item.renderSize!.height, greaterThan(0));
      final views = find.byType(
        defaultTargetPlatform == TargetPlatform.iOS ? UiKitView : AndroidView,
      );
      expect(views, findsWidgets);
      expect(
        tester.getSize(views.first).width,
        closeTo(item.renderSize!.width, 1),
      );
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final snapshot = await const MethodChannel(
          'ubidding_example/diagnostics',
        ).invokeMapMethod<String, Object?>('presentationSnapshot');
        (results[stage] as Map)['nativeGeometry'] = snapshot;
        var checked = 0;
        final templateClasses = <String>[];
        for (final scene in snapshot!['scenes'] as List) {
          for (final window in scene['windows'] as List) {
            final nodes = window['views'] as List;
            for (var i = 0; i < nodes.length; i++) {
              if (nodes[i]['class'] != 'UBNativeMountView') continue;
              final mount = nodes[i]['rectInWindow'] as Map;
              final depth = nodes[i]['depth'] as int;
              // Check the SDK Canvas and its first child (the actual template),
              // not only Flutter's synthetic PlatformView dimensions.
              for (
                var j = i + 1;
                j < nodes.length && nodes[j]['depth'] > depth;
                j++
              ) {
                if (nodes[j]['class'] != 'UMTNativeAdView') continue;
                expect(
                  j + 1,
                  lessThan(nodes.length),
                  reason: 'Truncated native view snapshot',
                );
                expect(
                  nodes[j + 1]['depth'],
                  greaterThan(nodes[j]['depth']),
                  reason: 'SDK template child missing from native Canvas',
                );
                final template = nodes[j + 1]['rectInWindow'] as Map;
                templateClasses.add(nodes[j + 1]['class'] as String);
                final left = (template['x'] as num).toDouble();
                final right = left + (template['width'] as num).toDouble();
                expect(left, greaterThanOrEqualTo((mount['x'] as num) - 1));
                expect(
                  right,
                  lessThanOrEqualTo(
                    (mount['x'] as num) + (mount['width'] as num) + 1,
                  ),
                );
                checked++;
                break;
              }
            }
          }
        }
        expect(
          checked,
          greaterThan(0),
          reason: 'No actual SDK template captured',
        );
        (results[stage] as Map)['templateClasses'] = templateClasses;
        const expectedClass = String.fromEnvironment(
          'QA_EXPECTED_TEMPLATE_CLASS',
        );
        if (expectedClass.isNotEmpty) {
          expect(
            templateClasses,
            contains(expectedClass),
            reason: 'Expected source not filled; do not accept another source',
          );
        }
      }
    }

    try {
      await tester.tap(find.text('整批加载 / 重新加载'));
      final old = await waitForTemplate('initial');
      await verify(old, originalHostWidth, 'native_width_initial');
      viewport.value = originalHostWidth - 32;
      await tester.pumpAndSettle();
      expect(find.text('容器宽度已变化，请重新加载'), findsOneWidget);
      expect(
        tester
            .widget<NativeItemCard>(find.byType(NativeItemCard).first)
            .item
            .requestId,
        old.item.requestId,
      );
      await tester.tap(find.text('整批加载 / 重新加载'));
      final next = await waitForTemplate('reloaded');
      expect(next.item.requestId, isNot(old.item.requestId));
      expect(old.item.isDisposed, true);
      await verify(next, originalHostWidth - 32, 'native_width_reloaded');
    } finally {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pumpAndSettle();
      viewport.dispose();
    }
  });
}
