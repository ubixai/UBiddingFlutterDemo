import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'package:ubidding_flutter/src/diagnostics/logging.dart';
import 'package:ubidding_flutter_example/widgets/plugin_log_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'default Info selector configures plugin without initializing SDK',
    (tester) async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel(UBiddingChannels.core),
        (call) async {
          calls.add(call);
          return null;
        },
      );
      try {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: PluginLogSettings())),
        );
        expect(find.text('info'), findsOneWidget);
        await tester.tap(find.byType(DropdownButton<UBiddingLogLevel>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('debug').last);
        await tester.pumpAndSettle();
        expect(UBidding.logLevel, UBiddingLogLevel.debug);
        expect(calls.single.method, 'configureLogging');
        expect(calls.single.arguments, containsPair('level', 'debug'));
      } finally {
        await tester.pumpWidget(const SizedBox());
        UBiddingDiagnostics.level = UBiddingLogLevel.info;
        messenger.setMockMethodCallHandler(
          const MethodChannel(UBiddingChannels.core),
          null,
        );
      }
    },
  );
}
