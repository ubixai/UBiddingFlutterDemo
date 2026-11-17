import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'package:ubidding_flutter_example/pages/native_page.dart';
import 'package:ubidding_flutter_example/widgets/native_video_controls.dart';
import 'support/native_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ubidding_flutter/native');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final viewCalls = <MethodCall>[];
  const methods = [
    'setVideoMute',
    'startVideo',
    'pauseVideo',
    'resumeVideo',
    'stopVideo',
  ];
  Future<Object?> Function(MethodCall)? commandHandler;
  late UBiddingNativeAd ad;

  setUp(() {
    calls.clear();
    viewCalls.clear();
    commandHandler = null;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getMaterial') {
        return {
          'title': call.arguments['adDataId'],
          'isVideo': call.arguments['adDataId'] != 'image',
        };
      }
      if (methods.contains(call.method)) {
        return await commandHandler?.call(call);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      viewCalls.add(call);
      return null;
    });
    ad = UBiddingNativeAd(
      request: const UBiddingAdRequest(slotId: 's', width: 264, height: 250),
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    debugDefaultTargetPlatformOverride = null;
  });
  Finder card(String id) => find.byKey(ValueKey('${ad.requestId}:$id'));
  Finder button(String id, String label) => find.descendant(
    of: card(id),
    matching: find.widgetWithText(TextButton, label),
  );
  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await ad.load();
    await emitAdEvent(
      ad,
      'loadSuccess',
      extra: {
        'nativeAdDatas': [
          {'adDataId': 'a', 'isExpress': false},
          {'adDataId': 'b', 'isExpress': false},
          {'adDataId': 'image', 'isExpress': false},
          {'adDataId': 'template', 'isExpress': true},
        ],
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                for (final item in ad.nativeAdDatas)
                  NativeItemCard(
                    key: ValueKey('${item.requestId}:${item.adDataId}'),
                    item: item,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void videoTest(String description, Future<void> Function(WidgetTester) body) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await ad.dispose();
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });
  }

  videoTest(
    'six video buttons select one item and retain view and cached material',
    (tester) async {
      await mount(tester);
      expect(find.byType(NativeVideoControls), findsNWidgets(2));
      expect(
        find.descendant(
          of: card('image'),
          matching: find.byType(NativeVideoControls),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: card('template'),
          matching: find.byType(NativeVideoControls),
        ),
        findsNothing,
      );
      final creates = viewCalls.where((c) => c.method == 'create').length;
      final firstKey = tester
          .widget<UiKitView>(find.byType(UiKitView).first)
          .key;
      for (final command in NativeVideoCommand.values) {
        await tester.tap(button('a', command.label));
        await tester.pumpAndSettle();
      }
      final commands = calls.where((c) => methods.contains(c.method)).toList();
      expect(commands.map((c) => c.method), [
        'setVideoMute',
        'setVideoMute',
        'startVideo',
        'pauseVideo',
        'resumeVideo',
        'stopVideo',
      ]);
      expect(commands.map((c) => c.arguments['adDataId']), everyElement('a'));
      expect(
        commands.map((c) => c.arguments['requestId']),
        everyElement(ad.requestId),
      );
      expect(commands.take(2).map((c) => c.arguments['muted']), [true, false]);
      await emitAdEvent(
        ad,
        'videoStatus',
        adDataId: 'a',
        extra: {'status': 99},
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('status: 99'), findsOneWidget);
      expect(find.textContaining('停止调用已返回（ACK）'), findsOneWidget);
      expect(calls.where((c) => c.method == 'load'), hasLength(1));
      expect(calls.where((c) => c.method == 'getMaterial'), hasLength(4));
      expect(viewCalls.where((c) => c.method == 'create'), hasLength(creates));
      expect(
        tester.widget<UiKitView>(find.byType(UiKitView).first).key,
        firstKey,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  videoTest(
    'pending command locks only one item; errors and detach do not fake playback',
    (tester) async {
      await mount(tester);
      final pending = Completer<Object?>();
      commandHandler = (_) => pending.future;
      final callback = tester.widget<TextButton>(button('a', '暂停')).onPressed!;
      callback();
      callback();
      await tester.pump();
      expect(calls.where((c) => c.method == 'pauseVideo'), hasLength(1));
      for (final label in ['暂停', '解绑此条', '释放此条']) {
        expect(tester.widget<TextButton>(button('a', label)).onPressed, isNull);
      }
      expect(tester.widget<TextButton>(button('b', '暂停')).onPressed, isNotNull);
      pending.completeError(
        PlatformException(
          code: 'sdk_error',
          message: 'fixture failure',
          details: {'nativeCode': 7},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('sdk_error'), findsOneWidget);
      expect(find.textContaining('nativeCode: 7'), findsOneWidget);
      expect(find.textContaining('ACK'), findsNothing);
      await tester.tap(button('a', '解绑此条'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(button('a', '暂停')).onPressed, isNull);
      await tester.tap(button('a', '重挂载此条'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(button('a', '暂停')).onPressed, isNotNull);
      await emitAdEvent(ad, 'dismiss', adDataId: 'a');
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(button('a', '暂停')).onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final invalidate in ['dispose', 'reload', 'leave']) {
    videoTest('late command result is ignored after $invalidate', (
      tester,
    ) async {
      await mount(tester);
      final pending = Completer<Object?>();
      commandHandler = (_) => pending.future;
      await tester.tap(button('a', '开始'));
      await tester.pump();
      if (invalidate == 'dispose') {
        await ad.nativeAdDatas.first.dispose();
      } else if (invalidate == 'reload') {
        await ad.load();
      } else {
        await tester.pumpWidget(const SizedBox());
      }
      pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.textContaining('开始调用已返回'), findsNothing);
      expect(tester.takeException(), isNull);
      if (invalidate != 'leave') {
        expect(tester.widget<TextButton>(button('a', '开始')).onPressed, isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  videoTest('preview wraps on narrow widths without invoking native channels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 400);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(nativeVideoControlsPreview());
    await tester.pumpAndSettle();
    expect(find.byType(Wrap), findsOneWidget);
    expect(find.byType(TextButton), findsNWidgets(6));
    expect(
      tester.getTopLeft(find.text('停止')).dy,
      greaterThan(tester.getTopLeft(find.text('静音')).dy),
    );
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
