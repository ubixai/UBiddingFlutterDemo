import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubidding_flutter_example/pages/banner_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('ubidding_flutter/banner');
  final calls = <MethodCall>[];
  var viewCreates = 0;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls.clear();
    viewCreates = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'isReady' ? true : null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') viewCreates++;
      return null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });
  Future<void> emit(
    Map identity,
    String type, [
    Map<String, Object?> extra = const {},
  ]) async {
    final done = Completer<void>();
    messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onAdEvent', {
          'schemaVersion': 1,
          'requestId': identity['requestId'],
          'slotId': identity['slotId'],
          'eventType': type,
          'source': type == 'renderSize' ? 'bridge' : 'sdk',
          'timestamp': 1,
          'extra': extra,
        }),
      ),
      (_) => done.complete(),
    );
    await done.future;
  }

  testWidgets(
    'example follows actual banner height without reloading or recreating its view',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: BannerPage()));
      await tester.tap(find.text('加载'));
      await tester.pumpAndSettle();
      final identity =
          calls.singleWhere((c) => c.method == 'create').arguments as Map;
      expect(identity['request']['width'], 320);
      expect(identity['request']['height'], 50);
      await emit(identity, 'loadSuccess');
      await tester.pumpAndSettle();
      final original = tester.state(find.byType(UiKitView));
      expect(tester.getSize(find.byType(UiKitView)), const Size(320, 50));
      for (final height in [75.0, 90.0, 60.0]) {
        await emit(identity, 'renderSize', {'width': 300.0, 'height': height});
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(UiKitView)), Size(320, height));
        expect(tester.state(find.byType(UiKitView)), same(original));
      }
      for (final height in [0.0, -1.0, double.nan, double.infinity]) {
        await emit(identity, 'renderSize', {'width': 300.0, 'height': height});
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(UiKitView)).height, 60);
      }
      expect(viewCreates, 1);
      expect(calls.where((c) => c.method == 'load').length, 1);
      expect(identity['request']['height'], 50);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await emit(identity, 'renderSize', {'width': 300.0, 'height': 200});
      expect(tester.takeException(), null);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
