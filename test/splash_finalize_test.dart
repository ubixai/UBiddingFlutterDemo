import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'package:ubidding_flutter_example/controllers/ad_page_controller.dart';
import 'package:ubidding_flutter_example/pages/ad_page.dart';
import 'support/native_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ubidding_flutter/splash');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  Future<Object?> Function(MethodCall)? handler;
  setUp(() {
    calls.clear();
    handler = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return await handler?.call(call);
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  AdPageController controller() => AdPageController(
    (slot) => UBiddingSplashAd(request: UBiddingAdRequest(slotId: slot)),
  );

  for (final terminal in ['loadSuccess', 'loadFailure']) {
    test('finalize accepts $terminal before ACK without auto show', () async {
      final c = controller();
      await c.load('s');
      handler = (call) async {
        if (call.method == 'finalizeAd') {
          await emitAdEvent(
            c.ad!,
            terminal,
            error: terminal == 'loadFailure'
                ? {
                    'code': 'load_failed',
                    'message': 'no fill',
                    'details': {'nativeCode': 600500},
                  }
                : null,
          );
        }
        return null;
      };
      expect(c.canFinalize, true);
      await c.finalizeAd();
      expect(
        c.phase,
        terminal == 'loadSuccess' ? AdPagePhase.ready : AdPagePhase.failed,
      );
      expect(c.canFinalize, false);
      expect(c.busy, false);
      expect(calls.where((c) => c.method == 'show'), isEmpty);
      expect(c.logs.join(), contains(terminal));
      if (terminal == 'loadFailure') expect(c.logs.join(), contains('600500'));
      await c.close();
      c.dispose();
    });
  }
  for (final available in [false, true]) {
    test(
      'direct Android result available=$available is displayed without an event or auto show',
      () async {
        final c = controller();
        await c.load('s');
        handler = (call) async => call.method == 'finalizeAd'
            ? {
                'available': available,
                'adInfo': {'adnName': 'fixture', 'ecpm': 8.5},
              }
            : null;
        await c.finalizeAd();
        expect(c.phase, available ? AdPagePhase.ready : AdPagePhase.loading);
        expect(c.logs.join(), contains('available=$available'));
        expect(c.logs.join(), contains('fixture'));
        expect(c.logs.join(), isNot(contains('loadSuccess')));
        expect(calls.where((c) => c.method == 'show'), isEmpty);
        expect(c.busy, false);
        await c.close();
        c.dispose();
      },
    );
  }
  test(
    'ACK leaves loading; invocation error only records its native fields',
    () async {
      final c = controller();
      expect(c.canFinalize, false);
      await c.finalizeAd();
      expect(calls, isEmpty);
      await c.load('s');
      await c.finalizeAd();
      expect(c.phase, AdPagePhase.loading);
      expect(c.canFinalize, true);
      expect(c.logs.join(), contains('ACK'));
      handler = (call) async {
        if (call.method == 'finalizeAd') {
          throw PlatformException(
            code: 'invalid_state',
            message: 'No active SDK session',
            details: {'nativeCode': 7},
          );
        }
        return null;
      };
      await c.finalizeAd();
      expect(c.phase, AdPagePhase.loading);
      expect(c.canFinalize, true);
      expect(c.logs.join(), contains('invalid_state'));
      expect(c.logs.join(), contains('nativeCode: 7'));
      await c.close();
      c.dispose();
    },
  );
  test('load ACK and a pending finalize disable repeated commands', () async {
    final loadAck = Completer<Object?>(), finalizeAck = Completer<Object?>();
    final loadEntered = Completer<void>(), finalizeEntered = Completer<void>();
    handler = (call) async {
      if (call.method == 'load') {
        loadEntered.complete();
        return loadAck.future;
      }
      if (call.method == 'finalizeAd') {
        finalizeEntered.complete();
        return finalizeAck.future;
      }
      return null;
    };
    final c = controller();
    final load = c.load('s');
    await loadEntered.future;
    expect(c.canFinalize, false);
    await c.finalizeAd();
    expect(calls.where((c) => c.method == 'finalizeAd'), isEmpty);
    loadAck.complete();
    await load;
    final finish = c.finalizeAd();
    await finalizeEntered.future;
    expect(c.canFinalize, false);
    await c.finalizeAd();
    expect(calls.where((c) => c.method == 'finalizeAd'), hasLength(1));
    finalizeAck.complete();
    await finish;
    expect(c.canFinalize, true);
    await c.close();
    c.dispose();
  });
  for (final leave in [false, true]) {
    test(
      'late finalize result is ignored after ${leave ? 'close' : 'replacement'}',
      () async {
        final ack = Completer<Object?>(), entered = Completer<void>();
        handler = (call) async {
          if (call.method == 'finalizeAd') {
            entered.complete();
            return ack.future;
          }
          return null;
        };
        final c = controller();
        await c.load('old');
        final oldId = c.ad!.requestId;
        final pending = c.finalizeAd();
        await entered.future;
        if (leave) {
          await c.close();
        } else {
          await c.release();
          await c.load('new');
        }
        final count = c.logs.length;
        ack.complete();
        await pending;
        expect(c.logs, hasLength(count));
        expect(c.phase, leave ? AdPagePhase.closed : AdPagePhase.loading);
        if (!leave) expect(c.ad!.requestId, isNot(oldId));
        await c.close();
        c.dispose();
      },
    );
  }
  testWidgets(
    'splash button follows loading and disappears from other formats',
    (tester) async {
      late UBiddingSplashAd ad;
      await tester.pumpWidget(
        MaterialApp(
          home: AdPage(
            label: '开屏',
            slot: 's',
            isSplash: true,
            createAd: (s) =>
                ad = UBiddingSplashAd(request: UBiddingAdRequest(slotId: s)),
          ),
        ),
      );
      final button = find.widgetWithText(ElevatedButton, '提前结束竞价');
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      await tester.tap(find.widgetWithText(ElevatedButton, '加载'));
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'finalizeAd'), hasLength(1));
      await emitAdEvent(ad, 'loadSuccess');
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: AdPage(
            key: const ValueKey('other'),
            label: '插屏',
            slot: 's',
            createAd: (s) =>
                UBiddingInterstitialAd(request: UBiddingAdRequest(slotId: s)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(button, findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
