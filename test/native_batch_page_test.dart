import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'package:ubidding_flutter_example/pages/native_page.dart';
import 'package:ubidding_flutter_example/widgets/native_layout.dart';
import 'support/native_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ubidding_flutter/native');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getMaterial' && call.arguments['adDataId'] == 'b') {
        return {'title': 'B material'};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (_) async => null,
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('template material presence never selects a self-render layout', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final ad = UBiddingNativeAd(
      request: const UBiddingAdRequest(slotId: 'slot', width: 320, height: 200),
    );
    final materialReads = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getMaterial') {
        final id = call.arguments['adDataId'] as String;
        materialReads.add(id);
        return id == 'template'
            ? {'title': 'SDK template material', 'isVideo': true}
            : null;
      }
      return null;
    });
    try {
      await ad.load();
      await emitAdEvent(
        ad,
        'loadSuccess',
        extra: {
          'nativeAdDatas': [
            {'adDataId': 'template', 'isExpress': true},
            {'adDataId': 'native', 'isExpress': false},
          ],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                for (final item in ad.nativeAdDatas) NativeItemCard(item: item),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(materialReads, ['template', 'native']);
      expect(find.byType(UiKitView), findsOneWidget);
      final view = tester.widget<UiKitView>(find.byType(UiKitView));
      final params = view.creationParams as Map;
      expect(params['adDataId'], 'template');
      expect(params.containsKey('nativeLayout'), false);
      expect(find.text('等待自渲染素材'), findsOneWidget);
      expect(find.text('静音'), findsNothing);
      expect(calls.where((call) => call.method == 'load'), hasLength(1));
    } finally {
      await tester.pumpWidget(const SizedBox());
      await ad.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });
  test('content width accounts for explicit list, card and inner padding', () {
    expect(nativeAdWidth(375.75), 319);
    expect(nativeAdWidth(320), 264);
    expect(nativeAdWidth(1024), 968);
    for (final width in [0.0, 56.0, double.infinity, double.nan]) {
      expect(nativeAdWidth(width), null);
    }
  });
  for (final mode in NativeDemoMode.values) {
    testWidgets('${mode.name} request uses its host height policy', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(MaterialApp(home: NativePage(mode: mode)));
        await tester.pumpAndSettle();
        await tester.tap(find.text('整批加载 / 重新加载'));
        await tester.pumpAndSettle();
        final create =
            calls.singleWhere((call) => call.method == 'create').arguments
                as Map;
        final request = create['request'] as Map;
        final layout = exampleNativeLayout(
          (request['width'] as num).toDouble(),
          UBiddingNativeMaterial.fromMap({'images': <Object>[]}),
        );
        expect(
          request['height'],
          mode == NativeDemoMode.custom ? layout.height : 250,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
  for (final screenWidth in [320.0, 375.75, 1024.0]) {
    testWidgets(
      'actual Card content measured with outer padding at $screenWidth',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(screenWidth, 1200);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          const MaterialApp(
            home: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.25),
              child: NativePage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calls.where((call) => call.method == 'load'), isEmpty);
        await tester.tap(find.text('整批加载 / 重新加载'));
        await tester.pumpAndSettle();
        final create =
            calls.singleWhere((call) => call.method == 'create').arguments
                as Map;
        final expected = nativeAdWidth(screenWidth - 24.5);
        expect(create['request']['width'], expected);
        final completed = Completer<void>();
        messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('onAdEvent', {
              'schemaVersion': 1,
              'requestId': create['requestId'],
              'slotId': create['slotId'],
              'eventType': 'loadSuccess',
              'timestamp': 1,
              'extra': const {
                'nativeAdDatas': [
                  {'adDataId': 'one', 'isExpress': true},
                ],
              },
            }),
          ),
          (_) => completed.complete(),
        );
        await completed.future;
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(UiKitView)).width, expected);
        await tester.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
  testWidgets(
    'template width is measured before load; resize waits for manual reload',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375.75, 1000);
      Future<void> send(
        Map create,
        String type,
        Map<String, Object?> extra,
      ) async {
        final done = Completer<void>();
        messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('onAdEvent', {
              'schemaVersion': 1,
              'requestId': create['requestId'],
              'slotId': create['slotId'],
              'eventType': type,
              'timestamp': 1,
              if (type == 'renderSize') 'adDataId': 'template',
              'extra': extra,
            }),
          ),
          (_) => done.complete(),
        );
        await done.future;
        await tester.pumpAndSettle();
      }

      try {
        await tester.pumpWidget(const MaterialApp(home: NativePage()));
        expect(calls.where((c) => c.method == 'load'), isEmpty);
        await tester.tap(find.text('整批加载 / 重新加载'));
        await tester.pumpAndSettle();
        final old =
            calls.singleWhere((c) => c.method == 'create').arguments as Map;
        expect(old['request']['width'], 319);
        await send(old, 'loadSuccess', {
          'nativeAdDatas': [
            {
              'adDataId': 'template',
              'isExpress': true,
              'expressMaterialType': 987654,
            },
          ],
        });
        expect(tester.getSize(find.byType(UiKitView)).width, 319);
        expect(find.text('模板素材类型：987654'), findsOneWidget);
        final key = tester.widget<UiKitView>(find.byType(UiKitView)).key;
        await send(old, 'renderSize', {'width': 319, 'height': 123});
        expect(tester.getSize(find.byType(UiKitView)), const Size(319, 123));
        expect(tester.widget<UiKitView>(find.byType(UiKitView)).key, key);
        tester.view.physicalSize = const Size(430, 1000);
        await tester.pumpAndSettle();
        expect(find.text('容器宽度已变化，请重新加载'), findsOneWidget);
        expect(calls.where((c) => c.method == 'load'), hasLength(1));
        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNotNull,
        );
        await tester.tap(find.text('整批加载 / 重新加载'));
        await tester.pumpAndSettle();
        for (
          var i = 0;
          i < 10 && calls.where((c) => c.method == 'create').length < 2;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 1));
        }
        final current =
            calls.where((c) => c.method == 'create').last.arguments as Map;
        expect(current['request']['width'], 374);
        expect(current['requestId'], isNot(old['requestId']));
        expect(calls.where((c) => c.method == 'dispose'), hasLength(1));
        await send(old, 'loadSuccess', {
          'nativeAdDatas': [
            {'adDataId': 'old', 'isExpress': true},
          ],
        });
        expect(find.byType(UiKitView), findsNothing);
        await send(current, 'loadSuccess', {
          'nativeAdDatas': [
            {'adDataId': 'template', 'isExpress': true},
          ],
        });
        expect(tester.getSize(find.byType(UiKitView)).width, 374);
        expect(find.text('容器宽度已变化，请重新加载'), findsNothing);
        expect(calls.where((c) => c.method == 'load'), hasLength(2));
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
  testWidgets('mixed batch has per-item controls and reload reuses one owner', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    try {
      await tester.pumpWidget(const MaterialApp(home: NativePage()));
      await tester.tap(find.text('整批加载 / 重新加载'));
      await tester.pumpAndSettle();
      final create =
          calls.singleWhere((c) => c.method == 'create').arguments as Map;
      final done = Completer<void>();
      messenger.handlePlatformMessage(
        'ubidding_flutter/native',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('onAdEvent', {
            'schemaVersion': 1,
            'requestId': create['requestId'],
            'slotId': create['slotId'],
            'eventType': 'loadSuccess',
            'timestamp': 1,
            'extra': const {
              'nativeAdDatas': [
                {'adDataId': 'a', 'isExpress': true},
                {'adDataId': 'b', 'isExpress': false},
                {'adDataId': 'c', 'isExpress': true},
              ],
            },
          }),
        ),
        (_) => done.complete(),
      );
      await done.future;
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsNWidgets(3));
      final items = tester
          .widgetList<NativeItemCard>(find.byType(NativeItemCard))
          .map((c) => c.item)
          .toList();
      expect((await items[1].getMaterial())!.title, 'B material');
      Finder card(int index) => find.byKey(
        ValueKey('${items[index].requestId}:${items[index].adDataId}'),
      );
      await tester.tap(
        find.descendant(of: card(1), matching: find.text('释放此条')),
      );
      await tester.pumpAndSettle();
      expect(items[1].isDisposed, true);
      expect(items[0].isDisposed, false);
      expect(items[2].isDisposed, false);
      expect(find.byType(UiKitView), findsNWidgets(2));
      await tester.tap(
        find.descendant(of: card(0), matching: find.text('解绑此条')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsOneWidget);
      await tester.tap(
        find.descendant(of: card(0), matching: find.text('重挂载此条')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsNWidgets(2));
      await tester.tap(find.text('整批加载 / 重新加载'));
      await tester.pumpAndSettle();
      expect(items.every((i) => i.isDisposed), true);
      expect(find.byType(UiKitView), findsNothing);
      expect(calls.where((c) => c.method == 'load'), hasLength(2));
      expect(calls.where((c) => c.method == 'create'), hasLength(1));
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets(
    'list scrolling detaches and remounts without disposing SDK data',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final ad = UBiddingNativeAd(
        request: const UBiddingAdRequest(
          slotId: 'slot',
          width: 100,
          height: 80,
        ),
      );
      try {
        await loadFixture(ad);
        final item = ad.nativeAdDatas.single;
        await tester.pumpWidget(
          MaterialApp(
            home: ListView(
              cacheExtent: 0,
              children: [
                NativeItemCard(key: ValueKey(item.adDataId), item: item),
                const SizedBox(height: 2200),
                const Text('end'),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(UiKitView), findsOneWidget);
        await tester.drag(find.byType(ListView), const Offset(0, -1800));
        await tester.pumpAndSettle();
        expect(find.byType(UiKitView), findsNothing);
        expect(item.isDisposed, false);
        await tester.drag(find.byType(ListView), const Offset(0, 2200));
        await tester.pumpAndSettle();
        expect(find.byType(UiKitView), findsOneWidget);
        expect(calls.where((c) => c.method == 'disposeAdData'), isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await ad.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
