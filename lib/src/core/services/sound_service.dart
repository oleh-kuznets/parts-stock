import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

/// Bundled UI sounds under `assets/sounds/` (shared with WiseWater Connect).
///
/// `audioplayers` resolves [AssetSource] paths relative to the default
/// `assets/` prefix — pass `sounds/…`, not `assets/sounds/…`.
///
/// [init] should be called once after `WidgetsFlutterBinding.ensureInitialized`
/// (i.e. from `main()`) so each [AudioPlayer] is preloaded and the first cue
/// fires without the cold-start hiccup that desktop embedders otherwise show.
class SoundService {
  factory SoundService() => _instance;
  SoundService._();

  static final SoundService _instance = SoundService._();

  static const String _savedPath = 'sounds/saved.mp3';
  static const String _dropPath = 'sounds/drop.mp3';
  static const String _resizeEndPath = 'sounds/resize_end.mp3';
  static const String _successInfoAlertPath = 'sounds/success_info_alert.wav';
  static const String _warnAlertPath = 'sounds/warn_alert.wav';
  static const String _dangerAlertPath = 'sounds/danger_alert.wav';
  static const String _tourCompletionPath = 'sounds/tour_completed.wav';

  /// Master output for all UI cues (0–1). Mirrors the WiseWater base level so
  /// the cues feel identical between the two apps.
  static const double _cueVolume = 0.58;

  /// Per-cue overrides, also matching the source mix.
  static const double _resizeEndHeaderVolume = _cueVolume * 0.72;

  AudioPlayer? _saved;
  AudioPlayer? _drop;
  AudioPlayer? _resizeEnd;
  AudioPlayer? _successInfo;
  AudioPlayer? _warnAlert;
  AudioPlayer? _dangerAlert;
  AudioPlayer? _tourCompletion;

  bool _enabled = true;
  Future<void>? _initFuture;

  /// Serializes alert / toast SFX so back-to-back cues do not clip each other.
  Future<void> _alertChain = Future<void>.value();

  /// "Currently in flight" + "min interval" guard for the drop cue. Without
  /// it, dropping multiple files in quick succession fires overlapping
  /// `setVolume / seek / resume` chains on the same `AudioPlayer`, which
  /// the macOS / Windows embedders do not always serialize internally —
  /// eventually the native side wedges and the UI thread starts blocking
  /// on the platform channel for audio.
  bool _dropBusy = false;
  DateTime _lastDropAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _minDropInterval = Duration(milliseconds: 120);

  bool get enabled => _enabled;

  void setEnabled(bool value) => _enabled = value;

  Future<void> init() => _initFuture ??= _preloadAll();

  Future<void> _preloadAll() async {
    if (!_platformAudioAvailable) return;
    try {
      await AudioCache.instance.loadAll(<String>[
        _savedPath,
        _dropPath,
        _resizeEndPath,
        _successInfoAlertPath,
        _warnAlertPath,
        _dangerAlertPath,
        _tourCompletionPath,
      ]);
    } catch (_) {
      // Best-effort warm-up; first play() will materialize the asset.
    }
    try {
      try {
        await _successInfoPlayer.setPlayerMode(PlayerMode.lowLatency);
      } catch (_) {
        // lowLatency is unsupported on some embedders; mediaPlayer is fine.
      }
      await _prepare(_savedPlayer, _savedPath);
      await _prepare(_dropPlayer, _dropPath);
      await _prepare(_resizeEndPlayer, _resizeEndPath);
      await _prepare(_successInfoPlayer, _successInfoAlertPath);
      await _prepare(_warnAlertPlayer, _warnAlertPath);
      await _prepare(_dangerAlertPlayer, _dangerAlertPath);
      await _prepare(_tourCompletionPlayer, _tourCompletionPath);
    } catch (_) {
      // Headless / missing codec — playback will silently no-op.
    }
  }

  Future<void> _prepare(
    AudioPlayer player,
    String path, {
    double volume = _cueVolume,
  }) async {
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(volume);
    await player.setSource(AssetSource(path));
    await player.pause();
  }

  /// Generic UI tap (buttons, sidebar items, segmented controls).
  ///
  /// Intentionally a no-op — the click cue is disabled product-wide. Kept on
  /// the API so existing call sites stay tidy and we can re-enable it later
  /// without churning the whole codebase.
  void tap() {}

  /// Persisted state changed — config saved, mapping applied, etc.
  void saved() {
    if (!_canPlay) return;
    unawaited(_play(_savedPlayer, _savedPath));
  }

  /// File added to the conversion queue.
  void drop() {
    if (!_canPlay || _dropBusy) return;
    final DateTime now = DateTime.now();
    if (now.difference(_lastDropAt) < _minDropInterval) return;
    _lastDropAt = now;
    _dropBusy = true;
    unawaited(
      _play(_dropPlayer, _dropPath).whenComplete(() {
        _dropBusy = false;
      }),
    );
  }

  /// Soft "release" cue used when dismissing dialogs / clearing the queue.
  void resizeEnd({bool headerBack = false}) {
    if (!_canPlay) return;
    unawaited(
      _play(
        _resizeEndPlayer,
        _resizeEndPath,
        volume: headerBack ? _resizeEndHeaderVolume : _cueVolume,
      ),
    );
  }

  /// Toast: success or info.
  void notificationSuccessInfoAlert() {
    if (!_canPlay) return;
    _enqueueAlert(() => _play(_successInfoPlayer, _successInfoAlertPath));
  }

  /// Toast: warn.
  void notificationWarnAlert() {
    if (!_canPlay) return;
    _enqueueAlert(() => _play(_warnAlertPlayer, _warnAlertPath));
  }

  /// Toast: danger / error.
  void notificationDangerAlert() {
    if (!_canPlay) return;
    _enqueueAlert(() => _play(_dangerAlertPlayer, _dangerAlertPath));
  }

  /// Conversion run finished without errors.
  void tourCompletion() {
    if (!_canPlay) return;
    unawaited(
      _play(_tourCompletionPlayer, _tourCompletionPath, stopFirst: true),
    );
  }

  void _enqueueAlert(Future<void> Function() play) {
    _alertChain = _alertChain.then((_) => play()).catchError((Object? _) {});
  }

  Future<void> _play(
    AudioPlayer player,
    String assetPath, {
    bool stopFirst = false,
    double volume = _cueVolume,
  }) async {
    if (!_canPlay) return;
    try {
      await (_initFuture ?? Future<void>.value());
      await player.setVolume(volume);
      if (stopFirst) {
        await player.stop();
        await player.setSource(AssetSource(assetPath));
        await player.pause();
      }
      await player.seek(Duration.zero);
      await player.resume();
    } catch (_) {
      try {
        await player.play(AssetSource(assetPath), volume: volume);
      } catch (_) {}
    }
  }

  bool get _canPlay => _enabled && _platformAudioAvailable;

  /// `audioplayers_windows` 4.3.0 sends event-channel messages off the Flutter
  /// platform thread with Flutter 3.41, which can freeze the Windows runner.
  /// Keep desktop startup stable by not creating Windows players at all.
  bool get _platformAudioAvailable =>
      defaultTargetPlatform != TargetPlatform.windows;

  AudioPlayer get _savedPlayer => _saved ??= AudioPlayer();
  AudioPlayer get _dropPlayer => _drop ??= AudioPlayer();
  AudioPlayer get _resizeEndPlayer => _resizeEnd ??= AudioPlayer();
  AudioPlayer get _successInfoPlayer => _successInfo ??= AudioPlayer();
  AudioPlayer get _warnAlertPlayer => _warnAlert ??= AudioPlayer();
  AudioPlayer get _dangerAlertPlayer => _dangerAlert ??= AudioPlayer();
  AudioPlayer get _tourCompletionPlayer => _tourCompletion ??= AudioPlayer();
}
