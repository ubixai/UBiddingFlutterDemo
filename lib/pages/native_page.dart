import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';
import '../demo_config.dart';
import '../widgets/native_layout.dart';
import '../widgets/native_video_controls.dart';

enum NativeDemoMode { template, custom }

const _listPadding = EdgeInsets.all(16);
const _cardMargin = EdgeInsets.all(4);
const _contentPadding = EdgeInsets.all(8);

/// The same content geometry is used before load and when mounting every item.
double? nativeAdWidth(double available) {
  final width =
      available -
      _listPadding.horizontal -
      _cardMargin.horizontal -
      _contentPadding.horizontal;
  return width.isFinite && width >= 1 ? width.floorToDouble() : null;
}

@Preview(name: '模板信息流 · 宽度测量', size: Size(375, 700))
Widget nativePagePreview() => MaterialApp(
  home: Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final width = nativeAdWidth(constraints.maxWidth);
        return Padding(
          padding: _listPadding,
          child: Card(
            margin: _cardMargin,
            child: Padding(
              padding: _contentPadding,
              child: SizedBox(
                width: width,
                height: 250,
                child: ColoredBox(
                  color: const Color(0xffeeeeee),
                  child: Center(
                    child: Text('request.width = container.width = $width'),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  ),
);

class NativePage extends StatefulWidget {
  const NativePage({super.key, this.mode = NativeDemoMode.template});
  final NativeDemoMode mode;
  @override
  State<NativePage> createState() => _NativePageState();
}

class _NativePageState extends State<NativePage> {
  UBiddingNativeAd? _ad;
  StreamSubscription<UBiddingAdEvent>? _events;
  late final _slot = TextEditingController(
    text: widget.mode == NativeDemoMode.template
        ? DemoConfig.forPlatform(defaultTargetPlatform).templateFeedSlotId
        : DemoConfig.forPlatform(defaultTargetPlatform).nativeFeedSlotId,
  );
  String _status = '等待加载';
  bool _loading = false;
  bool _invalidationReload = false;
  final _logs = <String>[];

  void _scheduleInvalidationReload(UBiddingNativeAd current) {
    if (_invalidationReload) return;
    final width = current.request.width;
    if (width == null) return;
    _invalidationReload = true;
    scheduleMicrotask(() {
      _invalidationReload = false;
      if (!mounted || !identical(_ad, current)) return;
      if (_loading) {
        _scheduleInvalidationReload(current);
        return;
      }
      unawaited(_load(width));
    });
  }

  Future<void> _load(double width) async {
    if (_loading) return;
    final slot = _slot.text.trim();
    setState(() => _loading = true);
    try {
      if (_ad?.request.slotId != slot || _ad?.request.width != width) {
        final old = _ad;
        _ad = null;
        // Invalidate identity first; stream cancellation must not hold up view teardown.
        final subscription = _events;
        _events = null;
        unawaited(subscription?.cancel());
        await old?.dispose();
        if (!mounted) return;
        _ad = UBiddingNativeAd(
          request: UBiddingAdRequest(
            slotId: slot,
            width: width,
            height: widget.mode == NativeDemoMode.custom
                ? exampleNativeAdHeight
                : 250,
          ),
        );
        final current = _ad!;
        _events = current.events.listen((event) {
          if (!mounted || !identical(_ad, current)) return;
          setState(() {
            _logs.insert(
              0,
              '${event.adDataId ?? "batch"}: ${event.type} ${event.extra}\n'
              '${event.error?.code ?? ""} ${event.error?.message ?? ""} '
              '${event.error?.domain ?? ""} ${event.error?.details ?? ""}',
            );
            if (_logs.length > 100) _logs.removeLast();
            if (event.adDataId == null) {
              _status = '${event.type} · ${current.nativeAdDatas.length} 条';
              if (event.error != null) {
                _status +=
                    '\n${event.error!.code} ${event.error!.message} '
                    '${event.error!.domain} ${event.error!.details}';
              }
              if (event.type == 'loadSuccess' ||
                  event.type == 'loadFailure' ||
                  event.type == 'bridgeError') {
                _loading = false;
              }
            }
          });
          if (event.adDataId == null &&
              event.extra['invalidatedBatch'] == true) {
            _scheduleInvalidationReload(current);
          }
        });
      }
      // The same owner reloads: every previous item and mounted view is invalidated.
      await _ad!.load();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = '$error';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    unawaited(_ad?.dispose());
    _slot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.mode == NativeDemoMode.template
            ? 'UBidding · 模板信息流'
            : 'UBidding · 自渲染信息流',
      ),
    ),
    body: ListView(
      padding: _listPadding,
      children: [
        Card(
          margin: _cardMargin,
          child: Padding(
            padding: _contentPadding,
            // Measure the same real Card content constraints as the mounted ads,
            // rather than reconstructing them from the screen width.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final available = constraints.maxWidth;
                final width = available.isFinite && available >= 1
                    ? available.floorToDouble()
                    : null;
                final changed = _ad != null && _ad!.request.width != width;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _slot,
                      enabled: !_loading,
                      decoration: const InputDecoration(labelText: 'Slot ID'),
                    ),
                    ElevatedButton(
                      onPressed: _loading || width == null
                          ? null
                          : () => _load(width),
                      child: const Text('整批加载 / 重新加载'),
                    ),
                    Text(_status),
                    if (width == null) const Text('等待有效的广告容器宽度'),
                    if (changed) const Text('容器宽度已变化，请重新加载'),
                  ],
                );
              },
            ),
          ),
        ),
        for (final item in _ad?.nativeAdDatas ?? <UBiddingNativeAdData>[])
          NativeItemCard(
            key: ValueKey('${item.requestId}:${item.adDataId}'),
            item: item,
          ),
        ExpansionTile(
          title: const Text('逐条事件'),
          children: [for (final line in _logs) SelectableText(line)],
        ),
      ],
    ),
  );
}

/// Host-owned state and layout for exactly one SDK object, also across list rebuilds.
class NativeItemCard extends StatefulWidget {
  const NativeItemCard({super.key, required this.item});
  final UBiddingNativeAdData item;
  @override
  State<NativeItemCard> createState() => _NativeItemCardState();
}

class _NativeItemCardState extends State<NativeItemCard> {
  late final _material = widget.item.getMaterial();
  late final StreamSubscription<UBiddingAdEvent> _events = widget.item.events
      .listen((event) {
        if (mounted) {
          setState(
            () => _status =
                '${event.type} · ${event.extra}\n'
                '${event.error?.code ?? ""} ${event.error?.message ?? ""} '
                '${event.error?.domain ?? ""} ${event.error?.details ?? ""}',
          );
        }
      });
  bool _attached = true;
  bool _videoBusy = false;
  String _commandStatus = '';
  String _status = '';

  bool get _canControlVideo =>
      !_videoBusy && _attached && widget.item.hasLoaded;

  Future<void> _runVideo(NativeVideoCommand command) async {
    if (!_canControlVideo) return;
    final item = widget.item;
    setState(() {
      _videoBusy = true;
      _commandStatus = '${command.label}调用中';
    });
    try {
      await switch (command) {
        NativeVideoCommand.mute => item.setVideoMute(true),
        NativeVideoCommand.unmute => item.setVideoMute(false),
        NativeVideoCommand.start => item.startVideo(),
        NativeVideoCommand.pause => item.pauseVideo(),
        NativeVideoCommand.resume => item.resumeVideo(),
        NativeVideoCommand.stop => item.stopVideo(),
      };
      if (mounted && identical(widget.item, item) && !item.isDisposed) {
        setState(
          () => _commandStatus = '${command.label}调用已返回（ACK），实际播放状态以 SDK 事件为准',
        );
      }
    } catch (error) {
      if (mounted && identical(widget.item, item) && !item.isDisposed) {
        setState(() => _commandStatus = '${command.label}调用异常：$error');
      }
    } finally {
      if (mounted && identical(widget.item, item)) {
        setState(() => _videoBusy = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _events;
  }

  @override
  void dispose() {
    unawaited(_events.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: _cardMargin,
    child: Padding(
      padding: _contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.item.adDataId} · ${widget.item.isExpress ? "模板" : "自渲染"}',
          ),
          if (widget.item.isExpress)
            Text('模板素材类型：${widget.item.expressMaterialType ?? "未提供"}'),
          Text(widget.item.isDisposed ? '已释放' : _status),
          Wrap(
            children: [
              TextButton(
                onPressed: widget.item.isDisposed || _videoBusy
                    ? null
                    : () => setState(() => _attached = !_attached),
                child: Text(_attached ? '解绑此条' : '重挂载此条'),
              ),
              TextButton(
                onPressed: widget.item.isDisposed || _videoBusy
                    ? null
                    : () async {
                        await widget.item.dispose();
                        if (mounted) setState(() {});
                      },
                child: const Text('释放此条'),
              ),
            ],
          ),
          FutureBuilder<UBiddingNativeMaterial?>(
            future: _material,
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('${snapshot.error}');
              if (snapshot.connectionState != ConnectionState.done) {
                return const Text('读取素材');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.item.isExpress && snapshot.data != null)
                    Text(
                      '评分（原始）：${snapshot.data!.platformExtra["score"] ?? "未提供"} · '
                      '下载次数（原始）：${snapshot.data!.platformExtra["downloadCountText"] ?? "未提供"}',
                    ),
                  if (!widget.item.isExpress && snapshot.data?.isVideo == true)
                    NativeVideoControls(
                      enabled: _canControlVideo,
                      onCommand: _runVideo,
                      commandStatus: _commandStatus,
                    ),
                  if (_attached && !widget.item.isDisposed)
                    Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: widget.item.request.width,
                        child: exampleNativeView(
                          context,
                          widget.item,
                          snapshot.data,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
