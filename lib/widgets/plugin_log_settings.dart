import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';

class PluginLogSettings extends StatefulWidget {
  const PluginLogSettings({super.key});
  @override
  State<PluginLogSettings> createState() => _PluginLogSettingsState();
}

class _PluginLogSettingsState extends State<PluginLogSettings> {
  UBiddingLogLevel _level = UBidding.logLevel;
  bool _busy = false;
  String? _error;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          const Text('Plugin 日志'),
          const SizedBox(width: 16),
          DropdownButton<UBiddingLogLevel>(
            value: _level,
            items: [
              for (final level in UBiddingLogLevel.values)
                DropdownMenuItem(value: level, child: Text(level.name)),
            ],
            onChanged: _busy
                ? null
                : (level) async {
                    if (level == null) return;
                    setState(() => _busy = true);
                    try {
                      await UBidding.configureLogging(level: level);
                      if (mounted) {
                        setState(() {
                          _level = level;
                          _error = null;
                        });
                      }
                    } catch (error) {
                      if (mounted) setState(() => _error = '$error');
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
          ),
        ],
      ),
      const Text('控制台筛选 UBiddingFlutter；不影响 SDK debugLogEnabled。'),
      if (_error != null) Text(_error!),
    ],
  );
}

@Preview(name: 'Plugin console log settings', size: Size(420, 140))
Widget pluginLogSettingsPreview() =>
    const MaterialApp(home: Scaffold(body: PluginLogSettings()));
