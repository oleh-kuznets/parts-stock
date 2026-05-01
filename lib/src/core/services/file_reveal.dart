import 'dart:io';

import 'package:path/path.dart' as p;

/// Opens a file or folder in the native file browser
/// (Finder on macOS, Explorer on Windows, xdg-open on Linux).
///
/// Returns `true` on success. Falls back to opening the parent directory
/// if [path] points at a file that the OS can't reveal directly.
class FileReveal {
  FileReveal._();

  /// Opens the directory in the platform's file browser.
  static Future<bool> openDirectory(String path) async {
    if (path.isEmpty) return false;
    try {
      final Directory dir = Directory(path);
      if (!dir.existsSync()) return false;
      return _runOpener(dir.path);
    } on Object {
      return false;
    }
  }

  /// Reveals a single file in its parent folder.
  ///
  /// macOS: highlights the file in Finder via `open -R`.
  /// Windows: uses `explorer /select`.
  /// Linux: opens the parent dir via xdg-open (no per-file highlight).
  static Future<bool> revealFile(String path) async {
    if (path.isEmpty) return false;
    try {
      final File file = File(path);
      if (!file.existsSync()) {
        // Best effort — if the file is gone, open the parent dir.
        return openDirectory(p.dirname(path));
      }
      if (Platform.isMacOS) {
        final ProcessResult res = await Process.run('open', <String>[
          '-R',
          file.absolute.path,
        ]);
        return res.exitCode == 0;
      }
      if (Platform.isWindows) {
        // Explorer returns 1 even on success, so we don't trust the exit code.
        await Process.run('explorer', <String>[
          '/select,${file.absolute.path}',
        ]);
        return true;
      }
      return openDirectory(p.dirname(file.absolute.path));
    } on Object {
      return false;
    }
  }

  static Future<bool> _runOpener(String absolutePath) async {
    if (Platform.isMacOS) {
      final ProcessResult res = await Process.run('open', <String>[
        absolutePath,
      ]);
      return res.exitCode == 0;
    }
    if (Platform.isWindows) {
      // `explorer` exits with 1 on success — trust the call instead.
      await Process.run('explorer', <String>[absolutePath]);
      return true;
    }
    if (Platform.isLinux) {
      final ProcessResult res = await Process.run('xdg-open', <String>[
        absolutePath,
      ]);
      return res.exitCode == 0;
    }
    return false;
  }
}
