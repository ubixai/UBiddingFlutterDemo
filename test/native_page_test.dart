import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubidding_flutter_example/main.dart';

void main() {
  testWidgets('feed modes have independent pages and placement defaults', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AdHomePage()));
    for (final mode in ['模板信息流', '自渲染信息流']) {
      await tester.tap(find.text(mode));
      await tester.pumpAndSettle();
      expect(find.text('UBidding · $mode'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, mode == '模板信息流' ? '5000001' : '5000000');
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
