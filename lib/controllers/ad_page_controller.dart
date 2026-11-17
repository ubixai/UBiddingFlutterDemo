import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:ubidding_flutter/ubidding_flutter.dart';

enum AdPagePhase { idle, loading, ready, showing, ended, failed, closed }

class AdPageController extends ChangeNotifier with WidgetsBindingObserver {
  AdPageController(this.createAd) {
    WidgetsBinding.instance.addObserver(this);
  }
  final UBiddingAd Function(String) createAd;
  UBiddingAd? ad;
  UBiddingNativeMaterial? nativeMaterial;
  StreamSubscription<UBiddingAdEvent>? _subscription;
  AdPagePhase phase = AdPagePhase.idle;
  bool attached = false;
  bool busy = false;
  bool _closed = false;
  bool _invalidationReload = false;
  int _generation = 0;
  String _slot = '';
  String? _bottomTemplate;
  double? _bottomHeight;
  double? _bottomRatio;
  Future<void>? _closing;
  final logs = <String>[];
  bool get canLoad =>
      !_closed &&
      !busy &&
      (phase == AdPagePhase.idle ||
          phase == AdPagePhase.failed ||
          phase == AdPagePhase.ended ||
          (phase == AdPagePhase.showing && ad is UBiddingFullScreenAd));
  bool get canPresent => !_closed && !busy && phase == AdPagePhase.ready;
  bool get canFinalize =>
      !_closed &&
      !busy &&
      phase == AdPagePhase.loading &&
      ad is UBiddingSplashAd &&
      !ad!.isDisposed;

  /// A fullscreen ad covers this page. Returning to the foreground means
  /// the ad is gone, even when the SDK never delivers dismiss.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _closed) return;
    if (phase != AdPagePhase.showing || ad is! UBiddingFullScreenAd) return;
    phase = AdPagePhase.ended;
    notifyListeners();
  }
  void log(Object message) {
    if (_closed) return;
    logs.insert(0, '${DateTime.now().toIso8601String()} · $message');
    if (logs.length > 100) logs.removeLast();
    notifyListeners();
  }

  Future<void> _release() async {
    final old = ad;
    ad = null;
    nativeMaterial = null;
    attached = false;
    final subscription = _subscription;
    _subscription = null;
    // Detach the listener without waiting. A late event no longer matches `ad`.
    unawaited(subscription?.cancel());
    await old?.dispose();
  }

  Future<void> load(
    String slot, {
    String? bottomTemplate,
    double? bottomHeight,
    double? bottomRatio,
  }) async {
    if (!canLoad) return;
    _slot = slot;
    _bottomTemplate = bottomTemplate;
    _bottomHeight = bottomHeight;
    _bottomRatio = bottomRatio;
    final generation = ++_generation;
    phase = AdPagePhase.loading;
    busy = true;
    notifyListeners();
    try {
      await _release();
      if (_closed || generation != _generation) return;
      final current = createAd(slot.trim());
      ad = current;
      _subscription = current.events.listen((event) {
        if (_closed || generation != _generation || !identical(ad, current)) {
          return;
        }
        switch (event.type) {
          case 'loadSuccess':
            if (phase == AdPagePhase.loading) {
              phase = AdPagePhase.ready;
              if (current is UBiddingEmbeddedAd) unawaited(present());
            }
          case 'show':
            // Dismiss is terminal. A late show must not disable Load.
            if (phase != AdPagePhase.ended &&
                phase != AdPagePhase.failed &&
                phase != AdPagePhase.closed) {
              phase = AdPagePhase.showing;
            }
          case 'loadFailure':
          case 'renderFailure':
          case 'showFailure':
            phase = AdPagePhase.failed;
            attached = false;
          case 'dismiss':
            phase = AdPagePhase.ended;
        }
        if (event.extra['invalidatedBatch'] == true) {
          _scheduleInvalidationReload();
        }
        log(
          '${event.type} · ${event.requestId}\n${event.error?.code ?? ''} ${event.error?.message ?? ''}\n${event.error?.domain ?? ''} ${event.error?.details ?? ''}',
        );
      });
      if (current is UBiddingSplashAd) {
        await current.load(
          bottomTemplate: bottomTemplate,
          bottomHeight: bottomHeight,
          bottomRatio: bottomRatio,
        );
      } else {
        await current.load();
      }
    } catch (error) {
      if (!_closed && generation == _generation) {
        phase = AdPagePhase.failed;
        log(error);
      }
    } finally {
      if (!_closed && generation == _generation) {
        busy = false;
        notifyListeners();
        if (phase == AdPagePhase.ready &&
            ad is UBiddingEmbeddedAd &&
            !attached) {
          unawaited(present());
        }
      }
    }
  }

  void _scheduleInvalidationReload() {
    if (_closed || _invalidationReload) return;
    _invalidationReload = true;
    final generation = _generation;
    // The detach event is delivered after the platform lifecycle call returns,
    // so a microtask runs once the new Activity is attached.
    scheduleMicrotask(() {
      _invalidationReload = false;
      if (_closed || generation != _generation) return;
      if (busy) {
        _scheduleInvalidationReload();
        return;
      }
      phase = AdPagePhase.ended;
      attached = false;
      unawaited(
        load(
          _slot,
          bottomTemplate: _bottomTemplate,
          bottomHeight: _bottomHeight,
          bottomRatio: _bottomRatio,
        ),
      );
    });
  }

  Future<void> finalizeAd() async {
    if (!canFinalize) return;
    final current = ad!;
    final generation = _generation;
    busy = true;
    notifyListeners();
    try {
      final result = await current.finalizeAd();
      if (!_closed && generation == _generation && identical(ad, current)) {
        if (result == null) {
          log('提前结束竞价调用已返回（ACK，无同步结果），加载结果以 SDK 事件为准');
        } else {
          if (phase == AdPagePhase.loading && result.available) {
            phase = AdPagePhase.ready;
          }
          log(
            '提前结束竞价同步结果：available=${result.available} · ADN=${result.adInfo?.adnName} · eCPM=${result.adInfo?.ecpm}；展示前仍检查 isReady',
          );
        }
      }
    } catch (error) {
      if (!_closed && generation == _generation && identical(ad, current)) {
        log('提前结束竞价调用异常：$error');
      }
    } finally {
      if (!_closed && generation == _generation && identical(ad, current)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> present({
    String? bottomViewFactoryId,
    String? bottomTemplate,
    double? bottomHeight,
    double? bottomRatio,
    bool useBottomView = true,
  }) async {
    if (!canPresent || attached) return;
    final current = ad;
    final generation = _generation;
    if (current == null) return;
    busy = true;
    notifyListeners();
    try {
      final ready = await current.isReady();
      if (_closed || generation != _generation) return;
      if (!ready) throw StateError('广告尚未就绪，请重新加载');
      if (current is UBiddingEmbeddedAd) {
        attached = true;
      } else if (current is UBiddingFullScreenAd) {
        phase = AdPagePhase.showing;
        if (current is UBiddingSplashAd) {
          await current.show(
            bottomViewFactoryId: bottomViewFactoryId,
            bottomTemplate: bottomTemplate,
            bottomHeight: bottomHeight,
            bottomRatio: bottomRatio,
            useBottomView: useBottomView,
          );
        } else {
          await current.show();
        }
        if (!_closed && generation == _generation) {
          log('展示调用已返回（ACK），实际结果以 SDK 事件为准');
        }
      }
    } catch (error) {
      if (!_closed && generation == _generation) {
        phase = AdPagePhase.failed;
        log(error);
      }
    } finally {
      if (!_closed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> inspect() async {
    final current = ad;
    if (_closed || busy || current == null) return;
    try {
      final ready = await current.isReady();
      final info = await current.adInfo;
      final status = defaultTargetPlatform == TargetPlatform.iOS
          ? await current.showStatus
          : null;
      if (!_closed && identical(current, ad)) {
        log(
          'ready=$ready · showStatus=$status · ADN=${info?.adnName} · eCPM=${info?.ecpm}',
        );
      }
    } catch (error) {
      log(error);
    }
  }

  void detach() {
    if (_closed) return;
    attached = false;
    notifyListeners();
  }

  Future<void> release() async {
    if (_closed) return;
    ++_generation;
    attached = false;
    busy = true;
    phase = AdPagePhase.idle;
    notifyListeners();
    try {
      await _release();
    } catch (error) {
      log(error);
    } finally {
      if (!_closed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    ++_generation;
    phase = AdPagePhase.closed;
    attached = false;
    await _release();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      close().catchError((Object error) {
        debugPrint('Ad cleanup: $error');
      }),
    );
    super.dispose();
  }
}
