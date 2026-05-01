import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/converter_config.dart';

/// Filesystem-backed persistence for the active [ConverterConfig].
///
/// Lives in the user's app-support directory (e.g.
/// `~/Library/Application Support/com.partsstock.app/config.json` on macOS,
/// `%APPDATA%\com.partsstock\Parts Stock\config.json` on Windows). The same
/// JSON shape is also what we read from / write to a sidecar `config.txt`
/// placed next to a source CSV.
class ConfigStorage {
  ConfigStorage({Directory? overrideDir}) : _overrideDir = overrideDir;

  static const String _filename = 'config.json';
  final Directory? _overrideDir;
  Directory? _resolvedDir;

  Future<Directory> _resolveDir() async {
    if (_resolvedDir != null) return _resolvedDir!;
    if (_overrideDir != null) {
      await _overrideDir.create(recursive: true);
      _resolvedDir = _overrideDir;
      return _overrideDir;
    }
    final Directory base = await getApplicationSupportDirectory();
    final Directory dir = Directory('${base.path}${Platform.pathSeparator}'
        'parts_stock');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _resolvedDir = dir;
    return dir;
  }

  Future<File> _file() async {
    final Directory dir = await _resolveDir();
    return File('${dir.path}${Platform.pathSeparator}$_filename');
  }

  Future<ConverterConfig> load() async {
    try {
      final File file = await _file();
      if (!file.existsSync()) {
        return ConverterConfig.defaults();
      }
      final String raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return ConverterConfig.defaults();
      }
      return ConverterConfig.fromJsonString(raw);
    } on Object {
      return ConverterConfig.defaults();
    }
  }

  Future<void> save(ConverterConfig config) async {
    final File file = await _file();
    await file.writeAsString(config.toPrettyJsonString(), flush: true);
  }

  Future<File> exportTo(String absolutePath, ConverterConfig config) async {
    final File target = File(absolutePath);
    await target.parent.create(recursive: true);
    await target.writeAsString(config.toPrettyJsonString(), flush: true);
    return target;
  }

  Future<ConverterConfig?> tryLoadSidecar(String inputCsvPath) async {
    final File source = File(inputCsvPath);
    final Directory parent = source.parent;
    final File sidecar = File(
      '${parent.path}${Platform.pathSeparator}config.txt',
    );
    if (!sidecar.existsSync()) {
      return null;
    }
    try {
      final String raw = await sidecar.readAsString();
      if (raw.trim().isEmpty) return null;
      return ConverterConfig.fromJsonString(raw);
    } on Object {
      return null;
    }
  }

  Future<String> resolvedDirPath() async {
    final Directory dir = await _resolveDir();
    return dir.path;
  }
}
