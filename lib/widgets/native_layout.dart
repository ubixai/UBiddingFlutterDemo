import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'shake_decoration.dart';

/// Shared by the self-render request and the host card's final layout.
const double exampleNativeAdHeight = 344;

/// Host policy, deliberately outside the plugin. Change this to design your own card.
UBiddingNativeLayout exampleNativeLayout(
  double width,
  UBiddingNativeMaterial material,
) {
  UBiddingNativeViewAttribute slot(
    double x,
    double y,
    double w,
    double h, {
    UBiddingNativeClickType click = UBiddingNativeClickType.none,
    double? fontSize,
    int? backgroundColor,
    int? textColor,
    UBiddingNativeTextAlignment textAlignment =
        UBiddingNativeTextAlignment.left,
  }) => UBiddingNativeViewAttribute(
    x: x,
    y: y,
    width: w,
    height: h,
    clickType: click,
    fontSize: fontSize,
    backgroundColor: backgroundColor,
    textColor: textColor,
    textAlignment: textAlignment,
  );
  final group = !material.isVideo && material.images.length > 1;
  final count = group ? material.images.length.clamp(1, 3) : 1;
  final imageWidth = (width - 16 - 4 * (count - 1)) / count;
  return UBiddingNativeLayout({
    UBiddingNativeSlot.rootView: slot(
      0,
      0,
      width,
      exampleNativeAdHeight,
      backgroundColor: 0xffffffff,
    ),
    if (material.icon != null)
      UBiddingNativeSlot.iconView: slot(
        8,
        8,
        40,
        40,
        click: UBiddingNativeClickType.normal,
      ),
    UBiddingNativeSlot.titleView: slot(
      56,
      8,
      width - 112,
      24,
      fontSize: 16,
      textColor: 0xff111111,
      click: UBiddingNativeClickType.normal,
    ),
    UBiddingNativeSlot.descriptionView: slot(
      56,
      32,
      width - 112,
      20,
      fontSize: 12,
      textColor: 0xff555555,
      click: UBiddingNativeClickType.normal,
    ),
    // Geometry only: native bridges register the SDK close slot, not an ad click.
    UBiddingNativeSlot.dislikeButton: slot(width - 48, 4, 44, 44),
    UBiddingNativeSlot.choiceView: slot(width - 32, 216, 24, 24),
    UBiddingNativeSlot.mainAdView: slot(
      8,
      60,
      imageWidth,
      184,
      click: UBiddingNativeClickType.normal,
    ),
    if (count > 1)
      UBiddingNativeSlot.imageView1: slot(
        12 + imageWidth,
        60,
        imageWidth,
        184,
        click: UBiddingNativeClickType.normal,
      ),
    if (count > 2)
      UBiddingNativeSlot.imageView2: slot(
        16 + imageWidth * 2,
        60,
        imageWidth,
        184,
        click: UBiddingNativeClickType.normal,
      ),
    UBiddingNativeSlot.ctaButton: slot(
      width - 116,
      252,
      108,
      40,
      fontSize: 14,
      backgroundColor: 0xff2576f6,
      textColor: 0xffffffff,
      textAlignment: UBiddingNativeTextAlignment.center,
      click: UBiddingNativeClickType.creative,
    ),
    UBiddingNativeSlot.adLabel: slot(
      8,
      252,
      28,
      40,
      fontSize: 11,
      textColor: 0xff666666,
    ),
    UBiddingNativeSlot.adLogoView: slot(40, 256, 28, 28),
    UBiddingNativeSlot.sourceView: slot(
      72,
      252,
      width - 196,
      40,
      fontSize: 11,
      textColor: 0xff666666,
    ),
    UBiddingNativeSlot.downloadView: slot(
      8,
      300,
      width - 16,
      36,
      fontSize: 11,
      textColor: 0xff555555,
    ),
  });
}

Widget exampleNativeView(
  BuildContext context,
  UBiddingAdViewHandle ad,
  UBiddingNativeMaterial? material,
) {
  if (ad.isExpress != false) return ad.buildView();
  if (material == null) return const Text('等待自渲染素材');
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 240) return const Text('自渲染布局至少需要 240 逻辑像素');
      final width = constraints.maxWidth.clamp(240.0, 600.0);
      return Align(
        alignment: Alignment.topLeft,
        child: _NativeLayoutMount(
          ad: ad,
          layout: exampleNativeLayout(width, material),
        ),
      );
    },
  );
}

/// A layout is a mount-time snapshot: remove the old PlatformView for one frame
/// before attaching the same offer with updated developer geometry.
class _NativeLayoutMount extends StatefulWidget {
  const _NativeLayoutMount({required this.ad, required this.layout});
  final UBiddingAdViewHandle ad;
  final UBiddingNativeLayout layout;
  @override
  State<_NativeLayoutMount> createState() => _NativeLayoutMountState();
}

class _NativeLayoutMountState extends State<_NativeLayoutMount> {
  bool _rebinding = false;
  @override
  void didUpdateWidget(_NativeLayoutMount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layout != widget.layout ||
        !identical(oldWidget.ad, widget.ad)) {
      _rebinding = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _rebinding = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) => _rebinding
      ? SizedBox(width: widget.layout.width, height: widget.layout.height)
      : widget.ad.buildView(
          nativeLayout: widget.layout,
          shakeViewBuilder: (context, shake) =>
              shake.status == UBiddingShakeStatus.enabled
              ? const ShakeDecoration()
              : const SizedBox.shrink(),
        );
}

/// Browser-compatible geometry preview; no PlatformView or SDK is started.
@Preview(
  name: 'Developer native-ad layout',
  size: Size(360, exampleNativeAdHeight),
)
Widget exampleNativeLayoutPreview() {
  final layout = exampleNativeLayout(
    360,
    UBiddingNativeMaterial.fromMap({'title': '广告标题'}),
  );
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: layout.width,
      height: layout.height,
      child: Stack(
        children: [
          for (final entry in layout.slots.entries)
            if (entry.key != UBiddingNativeSlot.rootView)
              Positioned(
                left: entry.value.x,
                top: entry.value.y,
                width: entry.value.width,
                height: entry.value.height,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xffeeeeee),
                    border: Border.all(color: const Color(0xff888888)),
                  ),
                  child: Text(
                    entry.key.name,
                    style: const TextStyle(fontSize: 10, color: Colors.black),
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}
