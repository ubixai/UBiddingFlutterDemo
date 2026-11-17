import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'package:ubidding_flutter_example/controllers/ad_page_controller.dart';

class FakeAd extends UBiddingFullScreenAd {
  FakeAd()
    : super(
        request: const UBiddingAdRequest(slotId: 'test'),
        type: UBiddingAdType.interstitial,
      );
  final stream = StreamController<UBiddingAdEvent>.broadcast(sync: true);
  int releases = 0;
  int shows = 0;
  @override
  Stream<UBiddingAdEvent> get events => stream.stream;
  @override
  Future<void> load() async {}
  @override
  Future<bool> isReady() async => true;
  @override
  Future<void> show() async {
    shows++;
  }

  @override
  Future<void> dispose() async {
    releases++;
    await super.dispose();
  }

  void emit(String type, {Map<String, Object?> extra = const {}}) => stream.add(
    UBiddingAdEvent(
      requestId: requestId,
      slotId: 'test',
      type: type,
      timestamp: 0,
      extra: extra,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'accepted load stays loading until success; close releases once',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('ubidding_flutter/interstitial'),
            (_) async => null,
          );
      final ad = FakeAd();
      final controller = AdPageController((_) => ad);
      await controller.load('test');
      expect(controller.phase, AdPagePhase.loading);
      expect(controller.canPresent, false);
      await controller.load('test');
      ad.emit('loadSuccess');
      expect(controller.canPresent, true);
      await controller.present();
      expect(ad.shows, 1);
      await controller.close();
      await controller.close();
      ad.emit('loadSuccess');
      expect(controller.phase, AdPagePhase.closed);
      expect(ad.releases, 1);
      controller.dispose();
      await ad.stream.close();
    },
  );

  testWidgets('closed interstitial can load again without leaving the page', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('ubidding_flutter/interstitial'),
          (_) async => null,
        );
    final opened = <FakeAd>[];
    final controller = AdPageController((_) {
      final ad = FakeAd();
      opened.add(ad);
      return ad;
    });
    await controller.load('slot');
    opened.single.emit('loadSuccess');
    await controller.present();
    opened.single.emit('show');
    expect(controller.phase, AdPagePhase.showing);
    expect(controller.canLoad, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(controller.phase, AdPagePhase.ended);
    opened.single.emit('show');
    expect(controller.phase, AdPagePhase.ended);
    expect(controller.canLoad, isTrue);

    await controller.load('slot');
    expect(opened, hasLength(2));
    expect(controller.phase, AdPagePhase.loading);
    controller.dispose();
    for (final ad in opened) {
      await ad.stream.close();
    }
  });

  testWidgets('invalidated batch reloads once', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('ubidding_flutter/interstitial'),
          (_) async => null,
        );
    var created = 0;
    FakeAd? current;
    final opened = <FakeAd>[];
    final controller = AdPageController((_) {
      created++;
      final ad = FakeAd();
      current = ad;
      opened.add(ad);
      return ad;
    });
    await controller.load('slot');
    expect(created, 1);
    current!.emit('bridgeError', extra: const {'invalidatedBatch': true});
    await tester.pump();
    await tester.pump();
    expect(created, 2);
    expect(controller.phase, AdPagePhase.loading);
    expect(controller.phase, AdPagePhase.loading);
    controller.dispose();
    for (final ad in opened) {
      await ad.stream.close();
    }
  });
}
