import '../widgets/shake_decoration.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widget_previews.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import '../controllers/ad_page_controller.dart';

class AdPage extends StatefulWidget {
  const AdPage({
    super.key,
    required this.label,
    required this.slot,
    required this.createAd,
    this.embeddedBuilder,
    this.isSplash = false,
  });
  final bool isSplash;
  final String label;
  final String slot;
  final UBiddingAd Function(String) createAd;
  final Widget Function(
    BuildContext,
    UBiddingEmbeddedAd,
    UBiddingNativeMaterial?,
  )?
  embeddedBuilder;
  @override
  State<AdPage> createState() => _AdPageState();
}

class _AdPageState extends State<AdPage> {
  late final controller = AdPageController(widget.createAd);
  late final slot = TextEditingController(text: widget.slot);
  bool _useBottom = false;
  bool? _loadedBottom;
  String get _bottomTemplate => defaultTargetPlatform == TargetPlatform.iOS
      ? 'UBExampleSplashBottomView'
      : 'example_splash_bottom';

  Future<void> _load() {
    _loadedBottom = widget.isSplash ? _useBottom : null;
    return controller.load(
      slot.text,
      bottomTemplate: widget.isSplash && _useBottom ? _bottomTemplate : null,
      bottomHeight: widget.isSplash && _useBottom ? 80 : null,
    );
  }

  Future<void> _present() {
    controller.log(
      '展示入口 · routeAnimation=${ModalRoute.of(context)?.animation?.status.name}',
    );
    if (!widget.isSplash) return controller.present();
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        _loadedBottom != null &&
        _useBottom != _loadedBottom) {
      controller.log('iOS 开屏底部在加载时固定，请重新加载后再展示');
      return Future<void>.value();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS)
      return controller.present();
    return _useBottom
        ? controller.present(bottomTemplate: _bottomTemplate, bottomHeight: 80)
        : controller.present(useBottomView: false);
  }

  @override
  void dispose() {
    controller.dispose();
    slot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text('UBidding · ${widget.label}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('状态：${controller.phase.name}'),
          TextField(
            controller: slot,
            enabled: controller.canLoad,
            decoration: const InputDecoration(labelText: 'Slot ID'),
          ),
          if (widget.isSplash)
            SplashBottomSwitch(
              value: _useBottom,
              onChanged: controller.busy
                  ? null
                  : (value) => setState(() => _useBottom = value),
            ),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: controller.canLoad ? _load : null,
                child: const Text('加载'),
              ),
              if (controller.ad is! UBiddingEmbeddedAd)
                ElevatedButton(
                  onPressed: controller.canPresent ? _present : null,
                  child: const Text('展示'),
                ),
              if (widget.isSplash)
                ElevatedButton(
                  onPressed: controller.canFinalize
                      ? controller.finalizeAd
                      : null,
                  child: const Text('提前结束竞价'),
                ),
            ],
          ),
          if (controller.attached && controller.ad is UBiddingEmbeddedAd)
            if (widget.embeddedBuilder != null)
              widget.embeddedBuilder!(
                context,
                controller.ad! as UBiddingEmbeddedAd,
                controller.nativeMaterial,
              )
            else
              (controller.ad! as UBiddingEmbeddedAd).buildView(
                shakeViewBuilder: (context, shake) =>
                    shake.status == UBiddingShakeStatus.enabled
                    ? const ShakeDecoration()
                    : const SizedBox.shrink(),
              ),
          ExpansionTile(
            title: const Text('诊断'),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: controller.ad != null && !controller.busy
                        ? controller.inspect
                        : null,
                    child: const Text('Ready / 广告信息'),
                  ),
                  TextButton(
                    onPressed: controller.canPresent ? _present : null,
                    child: const Text('挂载'),
                  ),
                  TextButton(
                    onPressed: controller.attached ? controller.detach : null,
                    child: const Text('解绑'),
                  ),
                  TextButton(
                    onPressed: controller.busy ? null : controller.release,
                    child: const Text('释放'),
                  ),
                  if (defaultTargetPlatform == TargetPlatform.iOS)
                    TextButton(
                      onPressed: () async {
                        try {
                          final snapshot =
                              await const MethodChannel(
                                'ubidding_example/diagnostics',
                              ).invokeMapMethod<String, Object?>(
                                'presentationSnapshot',
                              );
                          if (mounted) controller.log('窗口/转场/触摸命中：$snapshot');
                        } catch (error) {
                          if (mounted) controller.log('采集诊断失败：$error');
                        }
                      },
                      child: const Text('采集窗口/转场诊断'),
                    ),
                ],
              ),
              ...controller.logs.map((line) => SelectableText(line)),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Pure example UI; changing it never issues an ad request.
class SplashBottomSwitch extends StatelessWidget {
  const SplashBottomSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    title: const Text('使用底部（bottom）'),
    subtitle: const Text('加载和展示分别读取当前开关；切换不触发广告请求'),
    value: value,
    onChanged: onChanged,
  );
}

@Preview(name: '开屏共用 bottom 开关', size: Size(360, 180))
Widget splashBottomSwitchPreview() => MaterialApp(
  home: Scaffold(body: SplashBottomSwitch(value: false, onChanged: (_) {})),
);
