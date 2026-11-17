import 'package:flutter/foundation.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import '../demo_config.dart';
import 'ad_page.dart';

class BannerPage extends AdPage {
  BannerPage({super.key})
    : super(
        label: 'Banner',
        slot: DemoConfig.forPlatform(defaultTargetPlatform).bannerSlotId,
        createAd: (slot) => UBiddingBannerAd(
          request: UBiddingAdRequest(slotId: slot, width: 320, height: 50),
        ),
        embeddedBuilder: (context, ad, _) =>
            ad.buildView(height: ad.renderSize?.height),
      );
}
