import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';

Future<void> emitAdEvent(
  UBiddingAd ad,
  String type, {
  Map<String, Object?> extra = const {},
  Object? error,
  String? adDataId,
  int? loadGeneration,
}) async {
  if (ad is UBiddingNativeAd) {
    if (type == 'loadSuccess' && !extra.containsKey('nativeAdDatas')) {
      extra = {
        ...extra,
        'nativeAdDatas': [
          {
            'adDataId':
                'fixture-${ad.loadGeneration}-${extra['isExpress'] ?? true}-${extra['shakeStatus'] ?? 0}',
            'isExpress': extra['isExpress'] ?? true,
            'shakeStatus': extra['shakeStatus'] ?? 0,
          },
        ],
      };
    } else if (![
      'loadStart',
      'loadSuccess',
      'loadFailure',
      'adnRequest',
      'adnLoaded',
      'adnLoadFailure',
    ].contains(type)) {
      adDataId ??= ad.nativeAdDatas.isEmpty
          ? null
          : ad.nativeAdDatas.first.adDataId;
    }
  }
  final done = Completer<void>();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        'ubidding_flutter/${ad.type.name}',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('onAdEvent', {
            'schemaVersion': 1,
            'requestId': ad.requestId,
            'slotId': ad.request.slotId,
            'eventType': type,
            if (adDataId != null) 'adDataId': adDataId,
            'timestamp': 1,
            if (loadGeneration != null) 'loadGeneration': loadGeneration,
            'extra': extra,
            if (error != null) 'error': error,
          }),
        ),
        (_) => done.complete(),
      );
  await done.future;
}

Future<void> loadFixture(UBiddingAd ad) async {
  await ad.load();
  await emitAdEvent(ad, 'loadStart');
  await emitAdEvent(ad, 'loadSuccess');
}

/// Test host migrates the whole batch; no implicit-first API in the plugin.
Widget nativeFixtureView(
  UBiddingNativeAd ad, {
  double? width,
  double? height,
  UBiddingNativeLayout? nativeLayout,
  UBiddingShakeViewBuilder? shakeViewBuilder,
}) => StreamBuilder<UBiddingAdEvent>(
  stream: ad.events,
  builder: (context, _) => ad.nativeAdDatas.isEmpty
      ? const SizedBox.shrink()
      : ad.nativeAdDatas.single.buildView(
          width: width,
          height: height,
          nativeLayout: nativeLayout,
          shakeViewBuilder: shakeViewBuilder,
        ),
);
