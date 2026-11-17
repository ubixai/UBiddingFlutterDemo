import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubidding_flutter_example/main.dart';
import 'package:ubidding_flutter_example/pages/interstitial_page.dart';

void main() {
  testWidgets('startup gates navigation', (tester) async {
    await tester.pumpWidget(const UBiddingExampleApp());
    expect(find.text('同意并初始化'), findsOneWidget);
    expect(find.text('加载'), findsNothing);
  });
  testWidgets('show disabled before success', (tester) async {
    await tester.pumpWidget(MaterialApp(home: InterstitialPage()));
    expect(
      tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '展示'))
          .onPressed,
      isNull,
    );
    expect(find.text('初始化'), findsNothing);
  });
}
