import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  AppState({
    required this.storage,
    required ConverterConfig initialConfig,
    required String defaultOutputPath,
  })  : _config = initialConfig,
        _defaultOutputPath = defaultOutputPath;

  static Future<AppState> bootstrap() async {
    final ConfigStorage storage = ConfigStorage();
    final ConverterConfig initial = await storage.load();
    final String defaultOutput = await _resolveDefaultOutputPath();
    return AppState(
      storage: storage,
      initialConfig: initial,
      defaultOutputPath: defaultOutput,
    );
  }

  /// Resolves a writable default sink for converted files.
  ///
  /// Windows / Linux ship as plain executables, so we keep the user's
  /// expected behavior — `<dir-of-binary>/output/`. macOS apps run inside
  /// the sandbox and the bundle's `Contents/MacOS` directory is read-only,
  /// so we fall back to the per-app Documents container resolved by
  /// `path_provider` (visible in Finder under the app's container).
  static Future<String> _resolveDefaultOutputPath() async {
    if (Platform.isMacOS) {
      try {
        final Directory docs = await getApplicationDocumentsDirectory();
        return p.join(docs.path, 'output');
      } on Object {
        // Fall through — give the user *something* even if path_provider trips.
      }
    }
    return p.join(File(Platform.resolvedExecutable).parent.path, 'output');
  }

  final ConfigStorage storage;
  ConverterConfig _config;
  AppThemeMode _themeMode = AppThemeMode.system;
  String? _outputDirectoryOverride;
  bool _uiSoundsEnabled = true;
  final String _defaultOutputPath;

  ConverterConfig get config => _config;
  AppThemeMode get themeMode => _themeMode;
  String? get outputDirectoryOverride => _outputDirectoryOverride;
  bool get uiSoundsEnabled => _uiSoundsEnabled;

  /// `true` while a conversion run is in flight. The shell uses this to
  /// intercept the OS close request and warn the user before quitting.
  bool get isConverting => _isConverting;
  bool _isConverting = false;

  void setConverting(bool value) {
    if (_isConverting == value) return;
    _isConverting = value;
    notifyListeners();
  }

  /// CSV file paths dropped onto the app from the OS file browser.
  ///
  /// `AppShell` catches the OS drop event from any tab, switches to the
  /// converter, and broadcasts the paths here. `ConvertPage` subscribes to
  /// merge them into its queue. Using a broadcast stream (rather than a
  /// list on the notifier) means each drop is delivered exactly once and
  /// can't get re-applied during unrelated `notifyListeners` calls.
  Stream<List<String>> get droppedFiles => _droppedFilesController.stream;
  final StreamController<List<String>> _droppedFilesController =
      StreamController<List<String>>.broadcast();

  void emitDroppedFiles(List<String> paths) {
    if (paths.isEmpty) return;
    _droppedFilesController.add(paths);
  }

  @override
  void dispose() {
    _droppedFilesController.close();
    super.dispose();
  }

  /// Writable default sink resolved at bootstrap. Always usable on the
  /// current platform — even under macOS sandbox.
  String get defaultOutputPath => _defaultOutputPath;

  /// Active sink that the converter will actually write to right now.
  String get effectiveOutputPath =>
      _outputDirectoryOverride ?? _defaultOutputPath;

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
