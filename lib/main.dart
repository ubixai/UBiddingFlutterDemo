import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import 'demo_config.dart';
import 'widgets/version_info.dart';
import 'widgets/plugin_log_settings.dart';
import 'pages/interstitial_page.dart';
import 'pages/splash_page.dart';
import 'pages/rewarded_page.dart';
import 'pages/banner_page.dart';
import 'pages/native_page.dart';

void main() => runApp(const UBiddingExampleApp());

class UBiddingExampleApp extends StatelessWidget {
  const UBiddingExampleApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(home: StartupPage());
}

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});
  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  bool busy = false;
  String? error;
  Future<void> initialize() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // Initialization failures reach catch as PlatformException.
      await UBidding.initialize(
        UBiddingConfig(
          appId: DemoConfig.forPlatform(defaultTargetPlatform).appId,
          // Explicit demonstration policy, separate from the plugin's null defaults.
          sensorEnabled: false,
          privacy: const UBiddingPrivacyConfig(
            canUseLocation: false,
            canReadInstalledPackages: false,
            canUsePhoneState: false,
            canUseWifiState: false,
            canWriteExternalStorage: false,
            canUseOaid: false,
            canUseAndroidId: false,
            canUseMacAddress: false,
            canReadIdfa: false,
            canReadNetworkType: false,
            personalizedAds: false,
            programmaticRecommendation: false,
          ),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AdHomePage()),
      );
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('UBidding · 启动')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const PluginLogSettings(),
          const SelectableText('Flutter 适配器：${UBidding.pluginVersion}'),
          const Text('测试示例：确认已阅读宿主隐私说明并同意初始化。本示例显式关闭可选隐私访问；插件省略参数时沿用原生设置。'),
          if (busy) const CircularProgressIndicator(),
          if (error != null) SelectableText(error!),
          ElevatedButton(
            onPressed: busy ? null : initialize,
            child: Text(error == null ? '同意并初始化' : '重试初始化'),
          ),
        ],
      ),
    ),
  );
}

class AdHomePage extends StatelessWidget {
  const AdHomePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('广告类型')),
    body: ListView(
      children: [
        const VersionInfo(),
        const Padding(padding: EdgeInsets.all(16), child: PluginLogSettings()),
        for (final entry in <String, Widget Function()>{
          '开屏': () => SplashPage(),
          '插屏': () => InterstitialPage(),
          '激励': () => RewardedPage(),
          'Banner': () => BannerPage(),
          '模板信息流': () => const NativePage(mode: NativeDemoMode.template),
          '自渲染信息流': () => const NativePage(mode: NativeDemoMode.custom),
        }.entries)
          ListTile(
            title: Text(entry.key),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => entry.value())),
          ),
      ],
    ),
  );
}
