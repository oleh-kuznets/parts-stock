import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;

import '../models/converter_config.dart';

/// Single, pre-configured CSV codec used for both decoding source files and
/// encoding output rows. We stick with `\n` line endings to stay compatible
/// with the reference Python pipeline this converter replaces.
final Csv _csvCodec = Csv(lineDelimiter: '\n');

/// Streaming, chunk-aware CSV → CSV converter.
///
/// Each input file is processed in isolation, but all share the same
/// [ConverterConfig]. Rows that fail price parsing or violate the dedupe
/// constraint are silently skipped. The converter writes one or more
/// `*_partN.csv` chunks per input, each capped at [ConverterConfig.maxFileSizeMb].
class CsvConverter {
  CsvConverter({Directory? defaultOutputDir}) : _defaultOutputDir = defaultOutputDir;

  final Directory? _defaultOutputDir;

  Stream<ConversionEvent> convertAll({
    required List<String> inputPaths,
    required ConverterConfig config,
    String? outputDirectoryOverride,
    bool Function()? isCancelled,
  }) async* {
    for (final String input in inputPaths) {
      if (isCancelled?.call() ?? false) return;
      yield* convertOne(
        inputPath: input,
        config: config,
        outputDirectoryOverride: outputDirectoryOverride,
        isCancelled: isCancelled,
      );
    }
  }

  Stream<ConversionEvent> convertOne({
    required String inputPath,
    required ConverterConfig config,
    String? outputDirectoryOverride,
    bool Function()? isCancelled,
  }) async* {
    final File input = File(inputPath);
    if (!input.existsSync()) {
      yield ConversionEvent.error(
        inputPath: inputPath,
        message: 'Файл не знайдено: $inputPath',
      );
      return;
    }

    yield ConversionEvent.started(inputPath: inputPath);

    final Directory outputDir = await _resolveOutputDir(
      inputPath: inputPath,
      override: outputDirectoryOverride,
    );
    final String baseName = _baseName(input.path) + config.outputBaseSuffix;

    // Wrap the raw byte stream so we can report bytes-read progress to the
    // UI (the conversion hero shows a percentage based on total queue size,
    // not the file count — otherwise a single 1 GB file sits at 0%).
    int bytesRead = 0;
    final Stream<List<int>> byteStream = input.openRead().map((List<int> b) {
      bytesRead += b.length;
      return b;
    });
    final Stream<List<dynamic>> rowStream = byteStream
        .transform(utf8.decoder)
        .transform(_csvCodec.decoder);

    List<String> headerRaw = const <String>[];
    Map<String, int> headerIndex = const <String, int>{};
    bool sawHeader = false;
    final Set<String> seenDedupe = <String>{};
    final List<String> outputColumns = config.mappings
        .map((ColumnMapping m) => m.outputColumn)
        .toList(growable: false);

    int chunkIndex = 1;
    int rowsRead = 0;
    int rowsWritten = 0;
    int rowsSkipped = 0;
    int rowsFailed = 0;

    // Throttle progress emission so the UI never starves on huge rows or
    // races to a 60 Hz rebuild on tiny ones. We emit at most once per N
    // rows OR per ~512 KiB consumed, whichever fires first.
    int lastEmitBytes = 0;
    const int emitEveryBytes = 512 * 1024;

    _ChunkWriter writer = await _ChunkWriter.open(
      outputDir: outputDir,
      baseName: baseName,
      index: chunkIndex,
      header: outputColumns,
    );
    yield ConversionEvent.chunkOpened(
      inputPath: inputPath,
      chunkIndex: chunkIndex,
      chunkPath: writer.path,
    );

    final int maxBytes = config.maxFileSizeMb * 1024 * 1024;

    try {
      await for (final List<dynamic> row in rowStream) {
        // Honour user-requested cancellation between rows. We bail out
        // gracefully — the writer is closed in the `finally`-equivalent
        // block below and a `ConversionCancelled` event is emitted so the
        // UI can show the proper state for this file.
        if (isCancelled?.call() ?? false) {
          await writer.close();
          yield ConversionEvent.cancelled(
            inputPath: inputPath,
            outputDirectory: outputDir.path,
            chunks: chunkIndex,
            rowsRead: rowsRead,
            rowsWritten: rowsWritten,
            rowsSkipped: rowsSkipped,
            rowsFailed: rowsFailed,
            bytesRead: bytesRead,
          );
          return;
        }

        if (!sawHeader) {
          headerRaw = row.map((dynamic v) => '$v').toList(growable: false);
          headerIndex = <String, int>{
            for (int i = 0; i < headerRaw.length; i++)
              headerRaw[i].trim().toLowerCase(): i,
          };
          sawHeader = true;
          continue;
        }

        rowsRead += 1;

        // Per-row guard: any unexpected error during projection / dedupe is
        // treated as a single bad row — we count it under `rowsFailed` and
        // move on instead of nuking the whole conversion. IO errors from
        // the writer fall through to the outer catch (those are real).
        late _RowResult outcome;
        try {
          final List<String> stringRow = row
              .map((dynamic v) => v == null ? '' : '$v')
              .toList(growable: false);

          outcome = _projectRow(
            row: stringRow,
            headerIndex: headerIndex,
            config: config,
          );
          if (outcome.skipped) {
            rowsSkipped += 1;
            continue;
          }

          if (config.dedupe.enabled && config.dedupe.column.isNotEmpty) {
            final int? idx = headerIndex[config.dedupe.column.toLowerCase()];
            if (idx != null && idx < stringRow.length) {
              final String key = stringRow[idx].trim();
              if (key.isEmpty) {
                rowsSkipped += 1;
                continue;
              }
              if (!seenDedupe.add(key)) {
                rowsSkipped += 1;
                continue;
              }
            }
          }
        } on Object {
          rowsFailed += 1;
          continue;
        }

        await writer.writeRow(outcome.values!);
        rowsWritten += 1;

        if (writer.bytesWritten >= maxBytes) {
          await writer.close();
          yield ConversionEvent.chunkClosed(
            inputPath: inputPath,
            chunkIndex: chunkIndex,
            chunkPath: writer.path,
            byteSize: writer.bytesWritten,
          );
          chunkIndex += 1;
          writer = await _ChunkWriter.open(
            outputDir: outputDir,
            baseName: baseName,
            index: chunkIndex,
            header: outputColumns,
          );
          yield ConversionEvent.chunkOpened(
            inputPath: inputPath,
            chunkIndex: chunkIndex,
            chunkPath: writer.path,
          );
        }

        if (rowsWritten % 5000 == 0 ||
            (bytesRead - lastEmitBytes) >= emitEveryBytes) {
          lastEmitBytes = bytesRead;
          yield ConversionEvent.progress(
            inputPath: inputPath,
            rowsRead: rowsRead,
            rowsWritten: rowsWritten,
            rowsSkipped: rowsSkipped,
            rowsFailed: rowsFailed,
            bytesRead: bytesRead,
          );
        }
      }

      await writer.close();
      yield ConversionEvent.chunkClosed(
        inputPath: inputPath,
        chunkIndex: chunkIndex,
        chunkPath: writer.path,
        byteSize: writer.bytesWritten,
      );

      yield ConversionEvent.done(
        inputPath: inputPath,
        outputDirectory: outputDir.path,
        chunks: chunkIndex,
        rowsRead: rowsRead,
        rowsWritten: rowsWritten,
        rowsSkipped: rowsSkipped,
        rowsFailed: rowsFailed,
        bytesRead: bytesRead,
      );
    } on Object catch (error, stack) {
      try {
        await writer.close();
      } on Object {
        // Best effort: writer may already be closed.
      }
      yield ConversionEvent.error(
        inputPath: inputPath,
        message: 'Помилка під час обробки: $error',
        stackTrace: stack.toString(),
      );
    }
  }

  Future<Directory> _resolveOutputDir({
    required String inputPath,
    String? override,
  }) async {
    if (override != null && override.trim().isNotEmpty) {
      final Directory dir = Directory(override.trim());
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    if (_defaultOutputDir != null) {
      if (!_defaultOutputDir.existsSync()) {
        await _defaultOutputDir.create(recursive: true);
      }
      return _defaultOutputDir;
    }
    final Directory out = Directory(defaultExecutableOutputPath());
    if (!out.existsSync()) {
      await out.create(recursive: true);
    }
    return out;
  }

  static String _baseName(String inputPath) {
    final String name = p.basename(inputPath);
    final int dot = name.lastIndexOf('.');
    if (dot <= 0) return name;
    return name.substring(0, dot);
  }

  _RowResult _projectRow({
    required List<String> row,
    required Map<String, int> headerIndex,
    required ConverterConfig config,
  }) {
    final int? priceIdx =
        headerIndex[config.priceConfig.sourceColumn.toLowerCase()];
    double? markedPrice;
    if (priceIdx != null && priceIdx < row.length) {
      final String raw = row[priceIdx].trim().replaceAll(',', '.');
      final double? parsed = double.tryParse(raw);
      if (parsed == null) {
        if (config.priceConfig.dropZeroOrNegative) {
          return _RowResult.skip();
        }
      } else {
        if (parsed <= 0 && config.priceConfig.dropZeroOrNegative) {
          return _RowResult.skip();
        }
        markedPrice = _applyMargin(parsed, config);
        if (config.priceConfig.dropZeroOrNegative && markedPrice <= 0) {
          return _RowResult.skip();
        }
      }
    }

    final List<String> output = List<String>.filled(
      config.mappings.length,
      '',
      growable: false,
    );

    for (int i = 0; i < config.mappings.length; i++) {
      final ColumnMapping mapping = config.mappings[i];
      String value;
      if (mapping.kind == ColumnMappingKind.hardcoded) {
        value = mapping.hardcodedValue ?? '';
      } else {
        final String? source = mapping.sourceColumn?.trim().toLowerCase();
        if (source == null || source.isEmpty) {
          value = '';
        } else {
          final int? idx = headerIndex[source];
          if (idx == null || idx >= row.length) {
            value = '';
          } else {
            value = row[idx];
          }
        }
      }

      if (mapping.outputColumn == config.priceConfig.outputColumn &&
          markedPrice != null) {
        value = _formatPrice(markedPrice, config);
      }

      output[i] = value;
    }

    return _RowResult.ok(output);
  }

  double _applyMargin(double price, ConverterConfig config) {
    for (final MarginRule rule in config.margins) {
      if (rule.matches(price)) {
        final double adjusted = price * rule.multiplier;
        if (config.priceConfig.roundToInt) {
          final double rounded = adjusted.roundToDouble();
          if (config.priceConfig.minimumPrice > 0) {
            return rounded < config.priceConfig.minimumPrice
                ? config.priceConfig.minimumPrice
                : rounded;
          }
          return rounded;
        }
        return adjusted;
      }
    }
    return price;
  }

  String _formatPrice(double value, ConverterConfig config) {
    if (config.priceConfig.roundToInt) {
      return value.round().toString();
    }
    return value.toStringAsFixed(2);
  }
}

/// Best-effort synchronous fallback for the default output sink.
///
/// `AppState` resolves the real path asynchronously via `path_provider`
/// (sandbox-aware on macOS) and is the source of truth used by the UI.
/// This helper exists for legacy / test paths and intentionally avoids
/// returning anywhere inside the macOS `.app` bundle, which the sandbox
/// (and code-signing) make read-only at runtime.
String defaultExecutableOutputPath() {
  if (Platform.isMacOS) {
    // Under sandbox `$HOME` is the per-app container, so this lands in
    // `~/Library/Containers/<bundle>/Data/Documents/output` — writable.
    final String? home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return p.join(home, 'Documents', 'output');
    }
  }
  return p.join(File(Platform.resolvedExecutable).parent.path, 'output');
}

class _RowResult {
  const _RowResult._({required this.skipped, this.values});

  factory _RowResult.skip() => const _RowResult._(skipped: true);
  factory _RowResult.ok(List<String> values) =>
      _RowResult._(skipped: false, values: values);

  final bool skipped;
  final List<String>? values;
}

class _ChunkWriter {
  _ChunkWriter._(
    this.path,
    this._sink,
  );

  static Future<_ChunkWriter> open({
    required Directory outputDir,
    required String baseName,
    required int index,
    required List<String> header,
  }) async {
    final File file = File(
      p.join(outputDir.path, '${baseName}_part$index.csv'),
    );
    if (file.existsSync()) {
      await file.delete();
    }
    final IOSink sink = file.openWrite(encoding: utf8);
    final _ChunkWriter writer = _ChunkWriter._(file.path, sink);
    await writer._writeRaw(_encodeRow(header));
    return writer;
  }

  final String path;
  final IOSink _sink;
  int _bytesWritten = 0;
  bool _closed = false;

  int get bytesWritten => _bytesWritten;

  Future<void> writeRow(List<String> values) async {
    await _writeRaw(_encodeRow(values));
  }

  // NOTE: do NOT `await _sink.flush()` per row — that issues a syscall per
  // line and tanks throughput for large CSVs (50–100x slower in practice).
  // `IOSink.add` buffers internally; the final `close()` flushes & fsyncs.
  Future<void> _writeRaw(String line) async {
    final List<int> bytes = utf8.encode(line);
    _sink.add(bytes);
    _bytesWritten += bytes.length;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _sink.flush();
    await _sink.close();
  }

  static String _encodeRow(List<String> values) {
    return '${_csvCodec.encode(<List<dynamic>>[values])}\n';
  }
}

sealed class ConversionEvent {
  const ConversionEvent({required this.inputPath});

  factory ConversionEvent.started({required String inputPath}) =
      ConversionStarted;
  factory ConversionEvent.chunkOpened({
    required String inputPath,
    required int chunkIndex,
    required String chunkPath,
  }) = ConversionChunkOpened;
  factory ConversionEvent.chunkClosed({
    required String inputPath,
    required int chunkIndex,
    required String chunkPath,
    required int byteSize,
  }) = ConversionChunkClosed;
  factory ConversionEvent.progress({
    required String inputPath,
    required int rowsRead,
    required int rowsWritten,
    required int rowsSkipped,
    required int rowsFailed,
    required int bytesRead,
  }) = ConversionProgress;
  factory ConversionEvent.done({
    required String inputPath,
    required String outputDirectory,
    required int chunks,
    required int rowsRead,
    required int rowsWritten,
    required int rowsSkipped,
    required int rowsFailed,
    required int bytesRead,
  }) = ConversionDone;
  factory ConversionEvent.error({
    required String inputPath,
    required String message,
    String? stackTrace,
  }) = ConversionError;
  factory ConversionEvent.cancelled({
    required String inputPath,
    required String outputDirectory,
    required int chunks,
    required int rowsRead,
    required int rowsWritten,
    required int rowsSkipped,
    required int rowsFailed,
    required int bytesRead,
  }) = ConversionCancelled;

  final String inputPath;
}

class ConversionStarted extends ConversionEvent {
  const ConversionStarted({required super.inputPath});
}

class ConversionChunkOpened extends ConversionEvent {
  const ConversionChunkOpened({
    required super.inputPath,
    required this.chunkIndex,
    required this.chunkPath,
  });
  final int chunkIndex;
  final String chunkPath;
}

class ConversionChunkClosed extends ConversionEvent {
  const ConversionChunkClosed({
    required super.inputPath,
    required this.chunkIndex,
    required this.chunkPath,
    required this.byteSize,
  });
  final int chunkIndex;
  final String chunkPath;
  final int byteSize;
}

class ConversionProgress extends ConversionEvent {
  const ConversionProgress({
    required super.inputPath,
    required this.rowsRead,
    required this.rowsWritten,
    required this.rowsSkipped,
    required this.rowsFailed,
    required this.bytesRead,
  });
  final int rowsRead;
  final int rowsWritten;
  final int rowsSkipped;
  final int rowsFailed;
  final int bytesRead;
}

class ConversionDone extends ConversionEvent {
  const ConversionDone({
    required super.inputPath,
    required this.outputDirectory,
    required this.chunks,
    required this.rowsRead,
    required this.rowsWritten,
    required this.rowsSkipped,
    required this.rowsFailed,
    required this.bytesRead,
  });
  final String outputDirectory;
  final int chunks;
  final int rowsRead;
  final int rowsWritten;
  final int rowsSkipped;
  final int rowsFailed;
  final int bytesRead;
}

class ConversionError extends ConversionEvent {
  const ConversionError({
    required super.inputPath,
    required this.message,
    this.stackTrace,
  });
  final String message;
  final String? stackTrace;
}

/// Emitted when the user terminated the conversion via the UI's stop button.
/// Mirrors [ConversionDone]'s payload so the row that handled this file can
/// show the (partial) totals it managed to write before the abort.
class ConversionCancelled extends ConversionEvent {
  const ConversionCancelled({
    required super.inputPath,
    required this.outputDirectory,
    required this.chunks,
    required this.rowsRead,
    required this.rowsWritten,
    required this.rowsSkipped,
    required this.rowsFailed,
    required this.bytesRead,
  });
  final String outputDirectory;
  final int chunks;
  final int rowsRead;
  final int rowsWritten;
  final int rowsSkipped;
  final int rowsFailed;
  final int bytesRead;
}
