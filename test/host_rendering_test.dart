import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'package:ubidding_flutter_example/widgets/native_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('host explicitly positions image groups and download disclosures', () {
    final material = UBiddingNativeMaterial.fromMap({
      'images': [{}, {}, {}],
    });
    for (final width in [240.0, 360.0, 600.0]) {
      final layout = exampleNativeLayout(width, material);
      expect(layout.width, width);
      expect(layout.height, exampleNativeAdHeight);
      final cta = layout.slots[UBiddingNativeSlot.ctaButton]!;
      expect(cta.textAlignment, UBiddingNativeTextAlignment.center);
      expect((layout.toMap()['ctaButton'] as Map)['textAlignment'], 1);
      expect(cta.x, width - 116);
      expect(cta.width, 108);
      expect(cta.height, 40);
      expect(cta.clickType, UBiddingNativeClickType.creative);
      final dislike = layout.slots[UBiddingNativeSlot.dislikeButton]!;
      expect(dislike.clickType, UBiddingNativeClickType.none);
      expect((layout.toMap()['dislikeButton'] as Map)['clickType'], 0);
      expect(dislike.width, 44);
      expect(layout.slots[UBiddingNativeSlot.imageView1], isNotNull);
      expect(layout.slots[UBiddingNativeSlot.imageView2], isNotNull);
      expect(
        layout.slots[UBiddingNativeSlot.downloadView]!.clickType,
        UBiddingNativeClickType.none,
      );
    }
  });
  test(
    'dislike stays close-only for text, single image, group and video layouts',
    () {
      for (final raw in <Map<Object?, Object?>>[
        {},
        {
          'images': [{}],
        },
        {
          'images': [{}, {}, {}],
        },
        {
          'isVideo': true,
          'images': [{}],
        },
      ]) {
        for (final width in [240.0, 360.0, 600.0]) {
          final layout = exampleNativeLayout(
            width,
            UBiddingNativeMaterial.fromMap(raw),
          );
          final serialized = layout.toMap();
          final close = serialized['dislikeButton'] as Map;
          expect(close['clickType'], UBiddingNativeClickType.none.index);
          expect(close['width'], 44);
          expect(close['height'], 44);
          final clicks = serialized.entries
              .where((e) => (e.value as Map)['clickType'] != 0)
              .map((e) => e.key);
          expect(clicks, isNot(contains('dislikeButton')));
          expect(clicks, containsAll(['titleView', 'mainAdView', 'ctaButton']));
        }
      }
    },
  );
  testWidgets('layout preview renders without invoking a PlatformView', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Center(child: exampleNativeLayoutPreview())),
    );
    expect(find.text('titleView'), findsOneWidget);
    expect(find.text('downloadView'), findsOneWidget);
    expect(tester.takeException(), null);
  });
}
