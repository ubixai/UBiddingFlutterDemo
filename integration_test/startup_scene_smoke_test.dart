import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'package:ubidding_flutter_example/main.dart' as app;

// Scene/registration smoke only: no consent action, SDK initialization or ad requests.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'scene renders startup and the implicit engine has plugin channels',
    (tester) async {
      app.main();
      await tester.pumpAndSettle();
      expect(find.text('UBidding · 启动'), findsOneWidget);
      expect(find.text('同意并初始化'), findsOneWidget);
      expect(UBidding.pluginVersion, '4.2.3');
      expect(
        await UBidding.sdkVersion,
        defaultTargetPlatform == TargetPlatform.iOS ? '4.1.2.13' : '4.1.2.11',
      );
      expect(await UBidding.isInitialized, isFalse);
    },
  );
}
