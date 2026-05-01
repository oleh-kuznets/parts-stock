import 'package:flutter/widgets.dart';

/// `WidgetsFlutterBinding` that throttles the engine to a maximum frame
/// rate.
///
/// Why bother:
///  * Flutter desktop runs at the display's native vsync. On a 60 Hz panel
///    that's 60 FPS, on a 144 Hz it's 144 FPS, on a 240 Hz gaming monitor
///    it can be 240+ FPS. We want to honour higher rates (so animations
///    feel buttery on ProMotion / high-refresh setups) but spare the GPU
///    on extreme panels — there's no perceptual benefit beyond ~160 FPS
///    for a productivity app, and uncapped ticking burns battery.
///
/// How it works (the important bit):
///  * The engine drives every vsync as a *paired* call:
///    `handleBeginFrame` and then `handleDrawFrame`. The scheduler keeps a
///    phase machine — `handleBeginFrame` transitions `idle -> ... ->
///    midFrameMicrotasks`, then `handleDrawFrame` asserts that phase and
///    transitions back to `idle`.
///  * If we silently swallow `handleBeginFrame`, the phase stays `idle`
///    while the engine still calls `handleDrawFrame`, which trips the
///    `_schedulerPhase == SchedulerPhase.midFrameMicrotasks` assertion.
///  * So skipping has to be paired: when we drop a begin-frame, we must
///    also drop the matching draw-frame. That's what the `_skipNext` flag
///    below is for.
///  * After a skip we call [scheduleFrame] so the engine wakes us up on
///    the next vsync; the throttle math runs again, and the cap settles
///    on the requested FPS.
///  * A small tolerance is added to the minimum interval so a 165 Hz
///    panel running with a 160 cap doesn't get every other frame thrown
///    out by vsync jitter.
class FpsCapBinding extends WidgetsFlutterBinding {
  /// Initializes (or returns) the singleton binding.
  ///
  /// Call this from `main` *before* anything else touches
  /// `WidgetsBinding.instance` — the binding can only be installed once.
  static WidgetsBinding ensureInitialized({int maxFps = 160}) {
    if (!_initialized) {
      _initialized = true;
      _maxFps = maxFps;
      FpsCapBinding();
    }
    return WidgetsBinding.instance;
  }

  static bool _initialized = false;
  static int _maxFps = 160;

  late final Duration _minInterval =
      Duration(microseconds: 1000000 ~/ (_maxFps + 8));

  Duration? _lastAccepted;
  bool _skipNext = false;

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    final Duration ts = rawTimeStamp ?? Duration.zero;
    final Duration? last = _lastAccepted;
    if (last != null && (ts - last) < _minInterval) {
      // Mark the matching `handleDrawFrame` as a no-op so the scheduler's
      // phase machine stays consistent, then ask the engine for the next
      // vsync. We deliberately do NOT call `super.handleBeginFrame` —
      // that's the whole point of throttling.
      _skipNext = true;
      scheduleFrame();
      return;
    }
    _skipNext = false;
    _lastAccepted = ts;
    super.handleBeginFrame(rawTimeStamp);
  }

  @override
  void handleDrawFrame() {
    if (_skipNext) {
      _skipNext = false;
      return;
    }
    super.handleDrawFrame();
  }
}
