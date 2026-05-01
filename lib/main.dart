import 'dart:async';

import 'package:flutter/widgets.dart' show runApp;

import 'src/app/app.dart';
import 'src/app/app_state.dart';
import 'src/core/services/fps_cap_binding.dart';
import 'src/core/services/sound_service.dart';

Future<void> main() async {
  // Honour the panel's native refresh rate (60 / 120 / 144 Hz) but cap
  // at ~160 FPS so we don't melt 240 Hz gaming monitors for no good reason.
  FpsCapBinding.ensureInitialized(maxFps: 160);
  final AppState appState = await AppState.bootstrap();
  // Reflect the persisted master toggle before any cue can fire.
  SoundService().setEnabled(appState.uiSoundsEnabled);
  // Preload audio buffers so the very first tap / toast plays without the
  // typical desktop cold-start hiccup.
  unawaited(SoundService().init());
  runApp(PartsStockApp(appState: appState));
}
