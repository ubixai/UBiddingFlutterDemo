import 'package:flutter/foundation.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import '../demo_config.dart';
import 'ad_page.dart';

class FullscreenPage extends AdPage {
  FullscreenPage({
    super.key,
    required UBiddingAdType kind,
    required super.label,
  }) : super(
         isSplash: kind == UBiddingAdType.splash,
         slot: switch (kind) {
           UBiddingAdType.splash => DemoConfig.forPlatform(
             defaultTargetPlatform,
           ).splashSlotId,
           UBiddingAdType.rewarded => DemoConfig.forPlatform(
             defaultTargetPlatform,
           ).rewardedSlotId,
           _ => DemoConfig.forPlatform(
             defaultTargetPlatform,
           ).interstitialSlotId,
         },
         createAd: (slot) {
           final request = UBiddingAdRequest(
             slotId: slot,
             // Keep the SDK aggregate/source failure instead of racing it.
             fetchAdTimeOut: defaultTargetPlatform == TargetPlatform.android
                 ? 15000
                 : null,
           );
           return switch (kind) {
             UBiddingAdType.splash => UBiddingSplashAd(request: request),
             UBiddingAdType.rewarded => UBiddingRewardedAd(request: request),
             _ => UBiddingInterstitialAd(request: request),
           };
         },
       );
}
