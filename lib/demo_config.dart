import 'package:flutter/foundation.dart';

/// 示例宿主参数，广告位按平台和广告类型区分。
class DemoConfig {
  const DemoConfig({
    required this.appId,
    required this.splashSlotId,
    this.interstitialSlotId = '',
    this.rewardedSlotId = '',
    this.bannerSlotId = '',
    this.templateFeedSlotId = '',
    this.nativeFeedSlotId = '',
  });

  final String appId;
  final String splashSlotId;
  final String interstitialSlotId;
  final String rewardedSlotId;
  final String bannerSlotId;
  final String templateFeedSlotId;
  final String nativeFeedSlotId;

  static DemoConfig forPlatform(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.android:
        return const DemoConfig(
          appId: '184795459909',
          splashSlotId: '5000005',
          interstitialSlotId: '5000004',
          rewardedSlotId: '5000003',
          bannerSlotId: '5000002',
          templateFeedSlotId: '5000001',
          nativeFeedSlotId: '5000000',
        );
      case TargetPlatform.iOS:
        return const DemoConfig(
          appId: '162525628065',
          splashSlotId: '5000006',
          interstitialSlotId: '5000007',
          rewardedSlotId: '5000008',
          templateFeedSlotId: '5000009',
          nativeFeedSlotId: '5000010',
          bannerSlotId: '5000011',
        );
      default:
        return const DemoConfig(appId: '', splashSlotId: '');
    }
  }
}
