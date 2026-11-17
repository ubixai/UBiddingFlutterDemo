import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'package:ubidding_flutter_example/pages/fullscreen_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('example forwards only the Android SDK timeout', () async {
    try {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        for (final kind in [
          UBiddingAdType.splash,
          UBiddingAdType.interstitial,
          UBiddingAdType.rewarded,
        ]) {
          final ad = FullscreenPage(
            kind: kind,
            label: 'fixture',
          ).createAd('slot');
          expect(
            ad.request.fetchAdTimeOut,
            platform == TargetPlatform.android ? 15000 : null,
          );
          await ad.dispose();
        }
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
