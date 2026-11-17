import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'package:ubidding_flutter_example/pages/ad_page.dart';
import 'support/native_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ubidding_flutter/splash');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  Completer<Object?>? pending;
  setUp(() {
    calls.clear();
    pending = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'isReady') return true;
      if (call.method == 'load' && pending != null) return pending!.future;
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final loadBottom in [false, true]) {
      for (final showBottom in [false, true]) {
        for (final diagnostic in [false, true]) {
          testWidgets(
            '$platform load=$loadBottom show=$showBottom diagnostic=$diagnostic',
            (tester) async {
              debugDefaultTargetPlatformOverride = platform;
              late UBiddingSplashAd ad;
              try {
                await tester.pumpWidget(
                  MaterialApp(
                    home: AdPage(
                      label: '开屏',
                      slot: 's',
                      isSplash: true,
                      createAd: (s) => ad = UBiddingSplashAd(
                        request: UBiddingAdRequest(slotId: s),
                      ),
                    ),
                  ),
                );
                expect(
                  tester
                      .widget<SwitchListTile>(find.byType(SwitchListTile))
                      .value,
                  false,
                );
                expect(find.text('带底部加载'), findsNothing);
                expect(find.text('带底部展示'), findsNothing);
                expect(find.text('无底部展示'), findsNothing);
                Future<void> toggle(bool value) async {
                  final tile = tester.widget<SwitchListTile>(
                    find.byType(SwitchListTile),
                  );
                  tile.onChanged!(value);
                  await tester.pumpAndSettle();
                }

                if (loadBottom) await toggle(true);
                expect(calls, isEmpty);
                await tester.tap(find.widgetWithText(ElevatedButton, '加载'));
                await tester.pumpAndSettle();
                final load =
                    calls.singleWhere((c) => c.method == 'load').arguments
                        as Map;
                final template = platform == TargetPlatform.iOS
                    ? 'UBExampleSplashBottomView'
                    : 'example_splash_bottom';
                expect(load.containsKey('bottomTemplate'), loadBottom);
                expect(load.containsKey('bottomHeight'), loadBottom);
                if (loadBottom) {
                  expect(load['bottomTemplate'], template);
                  expect(load['bottomHeight'], 80);
                }
                await emitAdEvent(ad, 'loadSuccess');
                await tester.pumpAndSettle();
                final beforeToggle = calls.length;
                await toggle(showBottom);
                expect(calls, hasLength(beforeToggle));
                if (diagnostic) {
                  await tester.tap(find.text('诊断'));
                  await tester.pumpAndSettle();
                  await tester.ensureVisible(
                    find.widgetWithText(TextButton, '挂载'),
                  );
                  await tester.tap(find.widgetWithText(TextButton, '挂载'));
                } else {
                  await tester.tap(find.widgetWithText(ElevatedButton, '展示'));
                }
                await tester.pumpAndSettle();
                if (platform == TargetPlatform.iOS &&
                    showBottom != loadBottom) {
                  expect(calls.where((c) => c.method == 'show'), isEmpty);
                  if (!diagnostic) {
                    await tester.tap(find.text('诊断'));
                    await tester.pumpAndSettle();
                  }
                  expect(find.textContaining('请重新加载'), findsOneWidget);
                } else {
                  final show =
                      calls.singleWhere((c) => c.method == 'show').arguments
                          as Map;
                  if (platform == TargetPlatform.iOS) {
                    expect(show.containsKey('bottomTemplate'), false);
                    expect(show.containsKey('useBottomView'), false);
                  } else if (showBottom) {
                    expect(show['bottomTemplate'], template);
                    expect(show['bottomHeight'], 80);
                    expect(show.containsKey('useBottomView'), false);
                  } else {
                    expect(show['useBottomView'], false);
                    for (final key in [
                      'bottomTemplate',
                      'bottomViewFactoryId',
                      'bottomHeight',
                      'bottomRatio',
                    ]) {
                      expect(show.containsKey(key), false);
                    }
                  }
                }
                expect(calls.where((c) => c.method == 'load'), hasLength(1));
              } finally {
                await tester.pumpWidget(const SizedBox());
                await tester.pumpAndSettle();
                debugDefaultTargetPlatformOverride = null;
              }
            },
          );
        }
      }
    }
  }
  testWidgets('switch locks during commands and preview has no native calls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdPage(
          label: '开屏',
          slot: 's',
          isSplash: true,
          createAd: (s) =>
              UBiddingSplashAd(request: UBiddingAdRequest(slotId: s)),
        ),
      ),
    );
    pending = Completer<Object?>();
    await tester.tap(find.widgetWithText(ElevatedButton, '加载'));
    await tester.pump();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
    pending!.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    calls.clear();
    await tester.pumpWidget(splashBottomSwitchPreview());
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
