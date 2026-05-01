import 'dart:async';

import 'package:flutter/widgets.dart';

import 'src/app/app.dart';
import 'src/app/app_state.dart';
import 'src/core/services/sound_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppState appState = await AppState.bootstrap();
  // Reflect the persisted master toggle before any cue can fire.
  SoundService().setEnabled(appState.uiSoundsEnabled);
  // Preload audio buffers so the very first tap / toast plays without the
  // typical desktop cold-start hiccup.
  unawaited(SoundService().init());
  runApp(PartsStockApp(appState: appState));
}
