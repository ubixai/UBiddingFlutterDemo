import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'package:ubidding_flutter_example/widgets/version_info.dart';

void main() {
  testWidgets('shows adapter and actual platform SDK versions', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(UBiddingChannels.core),
          (call) async => '4.1.2',
        );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: VersionInfo())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Flutter 适配器：${UBidding.pluginVersion}'), findsOneWidget);
    expect(find.text('Android UBidding SDK：4.1.2'), findsOneWidget);
  });
  testWidgets(
    'version query failure shows retry instead of configured version',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(UBiddingChannels.core),
            (call) async => throw PlatformException(code: 'test_error'),
          );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: VersionInfo())),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('读取失败'), findsOneWidget);
      expect(find.text('重试读取版本'), findsOneWidget);
    },
  );
}
