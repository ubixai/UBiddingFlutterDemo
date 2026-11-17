import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'fullscreen_page.dart';

class InterstitialPage extends FullscreenPage {
  InterstitialPage({super.key})
    : super(kind: UBiddingAdType.interstitial, label: '插屏');
}
