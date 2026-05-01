import 'package:flutter/cupertino.dart';

import '../core/models/converter_config.dart';
import '../core/services/config_storage.dart';
import '../core/services/sound_service.dart';

/// Three-way theme switch — Cupertino has no built-in `ThemeMode`.
enum AppThemeMode { system, light, dark }

/// Holds the active [ConverterConfig] in memory and writes through to
/// [ConfigStorage] on every change.
///
/// Pages read from this notifier and call [updateConfig] (or one of the
/// targeted helpers) to mutate state. The notifier guarantees the on-disk
/// JSON stays in sync with what the UI shows.
class AppState extends ChangeNotifier {
  AppState({required this.storage, required ConverterConfig initialConfig})
    : _config = initialConfig;

  static Future<AppState> bootstrap() async {
    final ConfigStorage storage = ConfigStorage();
    final ConverterConfig initial = await storage.load();
    return AppState(storage: storage, initialConfig: initial);
  }

  final ConfigStorage storage;
  ConverterConfig _config;
  AppThemeMode _themeMode = AppThemeMode.system;
  String? _outputDirectoryOverride;
  bool _uiSoundsEnabled = true;

  ConverterConfig get config => _config;
  AppThemeMode get themeMode => _themeMode;
  String? get outputDirectoryOverride => _outputDirectoryOverride;
  bool get uiSoundsEnabled => _uiSoundsEnabled;

  Future<void> updateConfig(ConverterConfig next) async {
    if (identical(next, _config)) return;
    _config = next;
    notifyListeners();
    await storage.save(_config);
  }

  Future<void> replaceMappings(List<ColumnMapping> mappings) {
    return updateConfig(_config.copyWith(mappings: mappings));
  }

  Future<void> replaceMargins(List<MarginRule> margins) {
    return updateConfig(_config.copyWith(margins: margins));
  }

  Future<void> updatePriceConfig(PriceColumnConfig price) {
    return updateConfig(_config.copyWith(priceConfig: price));
  }

  Future<void> updateDedupe(DedupeConfig dedupe) {
    return updateConfig(_config.copyWith(dedupe: dedupe));
  }

  Future<void> updateChunkSizeMb(int megabytes) {
    final int clamped = megabytes.clamp(1, 4096);
    return updateConfig(_config.copyWith(maxFileSizeMb: clamped));
  }

  Future<void> updateOutputBaseSuffix(String suffix) {
    return updateConfig(_config.copyWith(outputBaseSuffix: suffix.trim()));
  }

  Future<void> applySidecar(ConverterConfig sidecar) {
    return updateConfig(sidecar);
  }

  void setThemeMode(AppThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void setUiSoundsEnabled(bool value) {
    if (_uiSoundsEnabled == value) return;
    _uiSoundsEnabled = value;
    SoundService().setEnabled(value);
    notifyListeners();
  }

  void setOutputDirectoryOverride(String? path) {
    if (_outputDirectoryOverride == path) return;
    _outputDirectoryOverride =
        (path == null || path.trim().isEmpty) ? null : path.trim();
    notifyListeners();
  }

  Future<void> resetToDefaults() {
    return updateConfig(ConverterConfig.defaults());
  }
}
