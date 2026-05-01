import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

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

  static const String _tapPath = 'sounds/tap.mp3';
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
  static double get _tapVolume => _cueVolume * 0.48;
  static const double _resizeEndHeaderVolume = _cueVolume * 0.72;

  final AudioPlayer _tap = AudioPlayer();
  final AudioPlayer _saved = AudioPlayer();
  final AudioPlayer _drop = AudioPlayer();
  final AudioPlayer _resizeEnd = AudioPlayer();
  final AudioPlayer _successInfo = AudioPlayer();
  final AudioPlayer _warnAlert = AudioPlayer();
  final AudioPlayer _dangerAlert = AudioPlayer();
  final AudioPlayer _tourCompletion = AudioPlayer();

  bool _enabled = true;
  Future<void>? _initFuture;

  /// Serializes alert / toast SFX so back-to-back cues do not clip each other.
  Future<void> _alertChain = Future<void>.value();

  bool get enabled => _enabled;

  void setEnabled(bool value) => _enabled = value;

  Future<void> init() => _initFuture ??= _preloadAll();

  Future<void> _preloadAll() async {
    try {
      await AudioCache.instance.loadAll(<String>[
        _tapPath,
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
        await _successInfo.setPlayerMode(PlayerMode.lowLatency);
      } catch (_) {
        // lowLatency is unsupported on some embedders; mediaPlayer is fine.
      }
      await _prepare(_tap, _tapPath, volume: _tapVolume);
      await _prepare(_saved, _savedPath);
      await _prepare(_drop, _dropPath);
      await _prepare(_resizeEnd, _resizeEndPath);
      await _prepare(_successInfo, _successInfoAlertPath);
      await _prepare(_warnAlert, _warnAlertPath);
      await _prepare(_dangerAlert, _dangerAlertPath);
      await _prepare(_tourCompletion, _tourCompletionPath);
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
  void tap() => unawaited(
    _play(_tap, _tapPath, stopFirst: true, volume: _tapVolume),
  );

  /// Persisted state changed — config saved, mapping applied, etc.
  void saved() => unawaited(_play(_saved, _savedPath));

  /// File added to the conversion queue.
  void drop() => unawaited(_play(_drop, _dropPath));

  /// Soft "release" cue used when dismissing dialogs / clearing the queue.
  void resizeEnd({bool headerBack = false}) => unawaited(
    _play(
      _resizeEnd,
      _resizeEndPath,
      volume: headerBack ? _resizeEndHeaderVolume : _cueVolume,
    ),
  );

  /// Toast: success or info.
  void notificationSuccessInfoAlert() => _enqueueAlert(
    () => _play(_successInfo, _successInfoAlertPath),
  );

  /// Toast: warn.
  void notificationWarnAlert() => _enqueueAlert(
    () => _play(_warnAlert, _warnAlertPath),
  );

  /// Toast: danger / error.
  void notificationDangerAlert() => _enqueueAlert(
    () => _play(_dangerAlert, _dangerAlertPath),
  );

  /// Conversion run finished without errors.
  void tourCompletion() => unawaited(
    _play(_tourCompletion, _tourCompletionPath, stopFirst: true),
  );

  void _enqueueAlert(Future<void> Function() play) {
    _alertChain = _alertChain.then((_) => play()).catchError((Object? _) {});
  }

  Future<void> _play(
    AudioPlayer player,
    String assetPath, {
    bool stopFirst = false,
    double volume = _cueVolume,
  }) async {
    if (!_enabled) return;
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
}
