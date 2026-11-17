import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubidding_flutter_example/demo_config.dart';

void main() {
  test('host app IDs and splash placements are platform-specific', () {
    expect(
      DemoConfig.forPlatform(TargetPlatform.android).appId,
      '184795459909',
    );
    expect(
      DemoConfig.forPlatform(TargetPlatform.android).splashSlotId,
      '5000005',
    );
    expect(DemoConfig.forPlatform(TargetPlatform.iOS).appId, '162525628065');
    expect(DemoConfig.forPlatform(TargetPlatform.iOS).splashSlotId, '5000006');
  });
  test('all placement types match the supplied platform screenshots', () {
    List<String> slots(DemoConfig config) => [
      config.splashSlotId,
      config.interstitialSlotId,
      config.rewardedSlotId,
      config.bannerSlotId,
      config.templateFeedSlotId,
      config.nativeFeedSlotId,
    ];
    expect(slots(DemoConfig.forPlatform(TargetPlatform.android)), [
      '5000005',
      '5000004',
      '5000003',
      '5000002',
      '5000001',
      '5000000',
    ]);
    expect(slots(DemoConfig.forPlatform(TargetPlatform.iOS)), [
      '5000006',
      '5000007',
      '5000008',
      '5000011',
      '5000009',
      '5000010',
    ]);
  });
}
