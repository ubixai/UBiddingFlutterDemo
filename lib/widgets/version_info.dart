import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';

/// Reads the linked native SDK, never substitutes the dependency lock version.
class VersionInfo extends StatefulWidget {
  const VersionInfo({super.key});
  @override
  State<VersionInfo> createState() => _VersionInfoState();
}

class _VersionInfoState extends State<VersionInfo> {
  late Future<String> version = UBidding.sdkVersion;
  @override
  Widget build(BuildContext context) {
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.android => 'Android',
      _ => defaultTargetPlatform.name,
    };
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SelectableText('Flutter 适配器：${UBidding.pluginVersion}'),
          FutureBuilder<String>(
            future: version,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      '$platform UBidding SDK：读取失败\n${snapshot.error}',
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => version = UBidding.sdkVersion),
                      child: const Text('重试读取版本'),
                    ),
                  ],
                );
              }
              return SelectableText(
                '$platform UBidding SDK：${snapshot.data ?? '读取中…'}',
              );
            },
          ),
        ],
      ),
    );
  }
}
