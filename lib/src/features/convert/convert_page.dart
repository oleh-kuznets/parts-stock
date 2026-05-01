import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../app/app_state.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_theme_preset.dart';
import '../../core/models/converter_config.dart';
import '../../core/services/csv_converter.dart';
import '../../core/services/file_reveal.dart';
import '../../core/services/sound_service.dart';
import '../../shared/widgets/animated_check.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_dialogs.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/hero_panel.dart';
import '../../shared/widgets/list_group.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/ring_progress.dart';
import '../../shared/widgets/section_card.dart';

class ConvertPage extends StatefulWidget {
  const ConvertPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<ConvertPage> createState() => _ConvertPageState();
}

class _ConvertPageState extends State<ConvertPage> {
  final List<_QueuedFile> _queue = <_QueuedFile>[];
  final Map<String, _ConversionRunState> _runStates =
      <String, _ConversionRunState>{};
  bool _running = false;
  bool _cancelRequested = false;
  StreamSubscription<ConversionEvent>? _subscription;
  StreamSubscription<List<String>>? _droppedFilesSub;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onState);
    // Pick up files dropped onto the shell from any tab.
    _droppedFilesSub =
        widget.appState.droppedFiles.listen(_ingestDroppedFiles);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onState);
    _droppedFilesSub?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  Future<void> _pickFiles() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: <String>['csv'],
      dialogTitle: 'Обери CSV файли',
      lockParentWindow: true,
    );
    if (result == null) return;
    final List<String> paths = <String>[
      for (final PlatformFile p in result.files)
        if (p.path != null) p.path!,
    ];
    await _addPathsToQueue(paths, playSound: true);
  }

  /// Shared queue-add path used by both the file picker and the OS-level
  /// drag-and-drop on `AppShell`. Skips duplicates and looks up the
  /// `config.txt` sidecar so the row's "apply config" affordance lights up
  /// automatically.
  Future<void> _addPathsToQueue(
    List<String> paths, {
    required bool playSound,
  }) async {
    if (paths.isEmpty || _running) return;
    final List<_QueuedFile> next = <_QueuedFile>[];
    for (final String path in paths) {
      if (_queue.any((_QueuedFile q) => q.path == path)) continue;
      if (next.any((_QueuedFile q) => q.path == path)) continue;
      final ConverterConfig? sidecar =
          await widget.appState.storage.tryLoadSidecar(path);
      next.add(_QueuedFile(path: path, sidecar: sidecar));
    }
    if (next.isEmpty || !mounted) return;
    if (playSound) SoundService().drop();
    setState(() => _queue.addAll(next));
  }

  Future<void> _ingestDroppedFiles(List<String> paths) async {
    if (_running) {
      if (!mounted) return;
      AppToast.show(
        context,
        'Конвертація йде — додам після того, як зупиниться',
        tone: AppToastTone.warning,
      );
      return;
    }
    // Sound is already played by the shell on drop; don't duplicate.
    await _addPathsToQueue(paths, playSound: false);
  }

  Future<void> _pickOutputDir() async {
    final String? selected = await getDirectoryPath(
      confirmButtonText: 'Вибрати',
    );
    if (selected == null) return;
    widget.appState.setOutputDirectoryOverride(selected);
  }

  void _removeFromQueue(_QueuedFile file) {
    setState(() {
      _queue.removeWhere((_QueuedFile q) => q.path == file.path);
      _runStates.remove(file.path);
    });
  }

  void _clearQueue() {
    setState(() {
      _queue.clear();
      _runStates.clear();
    });
  }

  Future<void> _applySidecar(_QueuedFile file) async {
    final ConverterConfig? sidecar = file.sidecar;
    if (sidecar == null) return;
    await widget.appState.applySidecar(sidecar);
    if (!mounted) return;
    AppToast.show(
      context,
      'Підвантажив config.txt — діє зараз',
      tone: AppToastTone.success,
    );
  }

  Future<void> _runConversion() async {
    if (_queue.isEmpty || _running) return;
    final CsvConverter converter = CsvConverter(
      defaultOutputDir: Directory(widget.appState.defaultOutputPath),
    );
    final ConverterConfig snapshot = widget.appState.config;

    setState(() {
      _running = true;
      _cancelRequested = false;
      for (final _QueuedFile q in _queue) {
        _runStates[q.path] = _ConversionRunState.queued();
      }
    });
    widget.appState.setConverting(true);

    bool encounteredError = false;
    bool wasCancelled = false;
    final Stream<ConversionEvent> stream = converter.convertAll(
      inputPaths: _queue.map((_QueuedFile q) => q.path).toList(growable: false),
      config: snapshot,
      outputDirectoryOverride: widget.appState.outputDirectoryOverride,
      isCancelled: () => _cancelRequested,
    );

    await _subscription?.cancel();
    _subscription = stream.listen(
      (ConversionEvent event) {
        if (event is ConversionError) {
          encounteredError = true;
        } else if (event is ConversionCancelled) {
          wasCancelled = true;
        }
        if (!mounted) return;
        setState(() {
          _runStates[event.inputPath] =
              (_runStates[event.inputPath] ?? _ConversionRunState.queued())
                  .merge(event);
        });
      },
      onError: (Object error, StackTrace stack) {
        encounteredError = true;
        if (!mounted) return;
        AppToast.show(context, 'Щось пішло не так: $error',
            tone: AppToastTone.danger);
      },
      onDone: () {
        widget.appState.setConverting(false);
        if (!mounted) return;
        setState(() {
          _running = false;
          _cancelRequested = false;
        });
        if (wasCancelled) {
          AppToast.show(
            context,
            'Зупинив. Часткові файли лишив у теці.',
            tone: AppToastTone.warning,
            silent: true,
          );
        } else if (!encounteredError) {
          SoundService().tourCompletion();
          AppToast.show(
            context,
            'Готово — сконвертував ${_queue.length} '
            '${_HeroContent._filesWord(_queue.length)}',
            tone: AppToastTone.success,
            silent: true,
          );
        }
      },
      cancelOnError: false,
    );
  }

  Future<void> _terminate() async {
    if (!_running || _cancelRequested) return;
    final bool? ok = await showAppConfirm(
      context,
      title: 'Зупинити конвертацію?',
      message: 'Закінчу поточний рядок і зупинюсь. '
          'Часткові файли лишаться в теці — їх можна буде видалити вручну.',
      confirmLabel: 'Зупинити',
      cancelLabel: 'Хай йде далі',
      destructive: true,
    );
    if (ok != true) return;
    setState(() => _cancelRequested = true);
  }

  // ---------------------------------------------------------------------------
  // Aggregate views over the run states — drive the hero panel + stat strip.

  _HeroPhase get _phase {
    if (_running) return _HeroPhase.running;
    if (_queue.isEmpty) return _HeroPhase.empty;
    final Iterable<_RunStatus> statuses = _queue.map(
      (_QueuedFile q) => _runStates[q.path]?.status ?? _RunStatus.queued,
    );
    if (statuses.any((_RunStatus s) => s == _RunStatus.error)) {
      return _HeroPhase.error;
    }
    if (statuses.every((_RunStatus s) => s == _RunStatus.done)) {
      return _HeroPhase.done;
    }
    return _HeroPhase.ready;
  }

  int get _filesDone => _queue
      .where((_QueuedFile q) => _runStates[q.path]?.status == _RunStatus.done)
      .length;

  int get _filesError => _queue
      .where((_QueuedFile q) => _runStates[q.path]?.status == _RunStatus.error)
      .length;

  ({int read, int written, int skipped, int failed, int chunks}) get _totals {
    int r = 0, w = 0, s = 0, f = 0, c = 0;
    for (final _ConversionRunState st in _runStates.values) {
      r += st.rowsRead;
      w += st.rowsWritten;
      s += st.rowsSkipped;
      f += st.rowsFailed;
      c += st.chunks;
    }
    return (read: r, written: w, skipped: s, failed: f, chunks: c);
  }

  /// Sum of bytes consumed across all queued files. Used to drive the hero
  /// ring as a real percentage instead of a `filesDone / queueLength` fraction
  /// (which sticks at 0 % whenever the user has just one big file).
  int get _bytesProcessed {
    int total = 0;
    for (final _QueuedFile q in _queue) {
      final _ConversionRunState? st = _runStates[q.path];
      if (st == null) continue;
      // Once a file is finished (done / cancelled / error) we credit its
      // full size so the bar lands cleanly on 100 % and doesn't undercount
      // because of the late-progress emission throttle.
      if (st.status == _RunStatus.done || st.status == _RunStatus.error) {
        total += q.sizeBytes;
      } else {
        total += st.bytesRead.clamp(0, q.sizeBytes);
      }
    }
    return total;
  }

  String _outputDirShortLabel() {
    final String? override = widget.appState.outputDirectoryOverride;
    if (override != null) return p.basename(override);
    if (Platform.isMacOS) return 'Documents/output';
    return 'output/ поряд із програмою';
  }

  String? _lastOutputDir() {
    for (final _ConversionRunState st in _runStates.values) {
      if (st.outputDirectory != null) return st.outputDirectory;
    }
    return null;
  }

  Future<void> _openOutputDir() async {
    final String dir =
        _lastOutputDir() ?? widget.appState.effectiveOutputPath;
    final bool ok = await FileReveal.openDirectory(dir);
    if (!mounted) return;
    if (!ok) {
      AppToast.show(
        context,
        'Не зміг відкрити теку: $dir',
        tone: AppToastTone.warning,
      );
    }
  }

  Future<void> _revealFile(String path) async {
    final bool ok = await FileReveal.revealFile(path);
    if (!mounted) return;
    if (!ok) {
      AppToast.show(
        context,
        'Не зміг показати файл: $path',
        tone: AppToastTone.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ConverterConfig config = widget.appState.config;
    final ({int read, int written, int skipped, int failed, int chunks})
        totals = _totals;
    final bool hasStats = totals.read > 0 ||
        totals.written > 0 ||
        totals.skipped > 0 ||
        totals.failed > 0 ||
        totals.chunks > 0;

    return PageScaffold(
      children: <Widget>[
        _ConvertHero(
          phase: _phase,
          queueLength: _queue.length,
          filesDone: _filesDone,
          filesError: _filesError,
          queueTotalBytes: _queue.fold<int>(
            0,
            (int acc, _QueuedFile q) => acc + q.sizeBytes,
          ),
          bytesProcessed: _bytesProcessed,
          outputLabel: _outputDirShortLabel(),
          isOverrideOutput: widget.appState.outputDirectoryOverride != null,
          cancelRequested: _cancelRequested,
          onAddFiles: _running ? null : _pickFiles,
          onStart: (_running || _queue.isEmpty) ? null : _runConversion,
          onStop: (_running && !_cancelRequested) ? _terminate : null,
          onReset: _running ? null : _clearQueue,
          onPickOutput: _pickOutputDir,
          onResetOutput: widget.appState.outputDirectoryOverride == null
              ? null
              : () => widget.appState.setOutputDirectoryOverride(null),
          onOpenOutput: _openOutputDir,
        ),
        if (hasStats)
          _StatStrip(
            read: totals.read,
            written: totals.written,
            skipped: totals.skipped,
            failed: totals.failed,
            chunks: totals.chunks,
          ),
        SectionCard(
          title: 'Файли в черзі',
          subtitle:
              'Тільки .csv. Якщо поряд лежить config.txt — підвантажимо його одним кліком.',
          leading: const SectionLeadingIcon(icon: CupertinoIcons.tray_arrow_down),
          trailing: Wrap(
            spacing: 8,
            children: <Widget>[
              if (_queue.isNotEmpty)
                AppButton.link(
                  icon: CupertinoIcons.clear_circled,
                  label: 'Очистити',
                  onPressed: _running ? null : _clearQueue,
                  compact: true,
                ),
              AppButton.secondary(
                icon: CupertinoIcons.add,
                label: 'Додати',
                onPressed: _running ? null : _pickFiles,
                compact: true,
              ),
            ],
          ),
          padding: _queue.isEmpty
              ? const EdgeInsets.fromLTRB(20, 18, 20, 20)
              : const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: _queue.isEmpty
              ? const _QueueEmpty()
              : ListGroup(
                  itemPadding: const EdgeInsets.symmetric(vertical: 14),
                  children: <Widget>[
                    for (int i = 0; i < _queue.length; i++)
                      _QueueRow(
                        file: _queue[i],
                        runState: _runStates[_queue[i].path],
                        running: _running,
                        onRemove: _running
                            ? null
                            : () => _removeFromQueue(_queue[i]),
                        onApplySidecar: _queue[i].sidecar == null
                            ? null
                            : () => _applySidecar(_queue[i]),
                        onReveal: () {
                          final String? path =
                              _runStates[_queue[i].path]?.lastChunkPath;
                          if (path != null) _revealFile(path);
                        },
                      ),
                  ],
                ),
        ),
        SectionCard(
          title: 'Що буде у готових файлах',
          subtitle: 'Коротко про активний конфіг — щоб не лізти в інші вкладки.',
          leading: const SectionLeadingIcon(icon: CupertinoIcons.eye),
          child: _ActiveConfigSummary(config: config),
        ),
      ],
    );
  }
}

// =============================================================================
// Hero panel
// =============================================================================

enum _HeroPhase { empty, ready, running, done, error }

class _ConvertHero extends StatelessWidget {
  const _ConvertHero({
    required this.phase,
    required this.queueLength,
    required this.filesDone,
    required this.filesError,
    required this.queueTotalBytes,
    required this.bytesProcessed,
    required this.outputLabel,
    required this.isOverrideOutput,
    required this.cancelRequested,
    required this.onAddFiles,
    required this.onStart,
    required this.onStop,
    required this.onReset,
    required this.onPickOutput,
    required this.onResetOutput,
    required this.onOpenOutput,
  });

  final _HeroPhase phase;
  final int queueLength;
  final int filesDone;
  final int filesError;
  final int queueTotalBytes;
  final int bytesProcessed;
  final String outputLabel;
  final bool isOverrideOutput;
  final bool cancelRequested;
  final VoidCallback? onAddFiles;
  final VoidCallback? onStart;
  final VoidCallback? onStop;
  final VoidCallback? onReset;
  final VoidCallback onPickOutput;
  final VoidCallback? onResetOutput;
  final VoidCallback onOpenOutput;

  @override
  Widget build(BuildContext context) {
    final HeroTone tone = switch (phase) {
      _HeroPhase.error => HeroTone.danger,
      _HeroPhase.done => HeroTone.success,
      _ => HeroTone.brand,
    };

    return HeroPanel(
      tone: tone,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool stack = constraints.maxWidth < 620;
          final Widget ring = _HeroRing(
            phase: phase,
            queueLength: queueLength,
            filesDone: filesDone,
            bytesProcessed: bytesProcessed,
            queueTotalBytes: queueTotalBytes,
          );
          final Widget content = _HeroContent(
            phase: phase,
            queueLength: queueLength,
            filesDone: filesDone,
            filesError: filesError,
            queueTotalBytes: queueTotalBytes,
            outputLabel: outputLabel,
            isOverrideOutput: isOverrideOutput,
            cancelRequested: cancelRequested,
            onAddFiles: onAddFiles,
            onStart: onStart,
            onStop: onStop,
            onReset: onReset,
            onPickOutput: onPickOutput,
            onResetOutput: onResetOutput,
            onOpenOutput: onOpenOutput,
          );

          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(child: ring),
                const SizedBox(height: 22),
                content,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ring,
              const SizedBox(width: 32),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _HeroRing extends StatelessWidget {
  const _HeroRing({
    required this.phase,
    required this.queueLength,
    required this.filesDone,
    required this.bytesProcessed,
    required this.queueTotalBytes,
  });

  final _HeroPhase phase;
  final int queueLength;
  final int filesDone;
  final int bytesProcessed;
  final int queueTotalBytes;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;

    final List<Color> gradient = switch (phase) {
      _HeroPhase.error => const <Color>[
          Color(0xFFFF8C8C),
          Color(0xFFFF4E4E),
        ],
      _HeroPhase.done => const <Color>[
          Color(0xFF8FF0BD),
          Color(0xFF1AC56D),
        ],
      _ => const <Color>[
          Color(0xFFB6E1FF),
          Color(0xFF3A82FF),
        ],
    };

    // Real bytes-based progress while running. Falls back to indeterminate
    // (`null`) only if we have no idea about the queue size yet — otherwise
    // a single big file would sit at 0 % until it fully finished.
    final double runningRatio = queueTotalBytes <= 0
        ? 0
        : (bytesProcessed / queueTotalBytes).clamp(0.0, 1.0);

    final double? value = switch (phase) {
      _HeroPhase.empty => 0,
      _HeroPhase.ready => 0,
      _HeroPhase.running =>
        queueTotalBytes <= 0 ? null : runningRatio,
      _HeroPhase.done => 1,
      _HeroPhase.error => 1,
    };

    final Widget center = switch (phase) {
      _HeroPhase.empty => Icon(
          CupertinoIcons.cloud_upload,
          size: 40,
          color: CupertinoColors.white.withValues(alpha: 0.92),
        ),
      _HeroPhase.ready => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '$queueLength',
              style: t.headlineLarge.copyWith(
                color: CupertinoColors.white,
                fontSize: 44,
                height: 1,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              queueLength == 1 ? 'файл' : 'у черзі',
              style: t.labelSmall.copyWith(
                color: CupertinoColors.white.withValues(alpha: 0.75),
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      _HeroPhase.running => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${(runningRatio * 100).round()}%',
              style: t.headlineLarge.copyWith(
                color: CupertinoColors.white,
                fontSize: 38,
                height: 1,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$filesDone / $queueLength ${_HeroContent._filesWord(queueLength)}',
              style: t.labelSmall.copyWith(
                color: CupertinoColors.white.withValues(alpha: 0.75),
                letterSpacing: 0.6,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ],
        ),
      _HeroPhase.done => const AnimatedCheck(
          size: 70,
          strokeWidth: 7,
        ),
      _HeroPhase.error => const Icon(
          CupertinoIcons.exclamationmark,
          size: 52,
          color: CupertinoColors.white,
        ),
    };

    return RingProgress(
      size: 156,
      strokeWidth: 11,
      value: value,
      gradientColors: gradient,
      trackColor: CupertinoColors.white.withValues(alpha: 0.12),
      center: center,
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({
    required this.phase,
    required this.queueLength,
    required this.filesDone,
    required this.filesError,
    required this.queueTotalBytes,
    required this.outputLabel,
    required this.isOverrideOutput,
    required this.cancelRequested,
    required this.onAddFiles,
    required this.onStart,
    required this.onStop,
    required this.onReset,
    required this.onPickOutput,
    required this.onResetOutput,
    required this.onOpenOutput,
  });

  final _HeroPhase phase;
  final int queueLength;
  final int filesDone;
  final int filesError;
  final int queueTotalBytes;
  final String outputLabel;
  final bool isOverrideOutput;
  final bool cancelRequested;
  final VoidCallback? onAddFiles;
  final VoidCallback? onStart;
  final VoidCallback? onStop;
  final VoidCallback? onReset;
  final VoidCallback onPickOutput;
  final VoidCallback? onResetOutput;
  final VoidCallback onOpenOutput;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;

    final (String title, String subtitle, String? eyebrow) copy =
        switch (phase) {
      _HeroPhase.empty => (
        'Готовий, коли ти готовий',
        'Кинь сюди CSV — і поїхали.',
        'Старт',
      ),
      _HeroPhase.ready => (
        'Поїхали?',
        '$queueLength ${_filesWord(queueLength)}, всього ${_formatBytes(queueTotalBytes)}.',
        'У черзі',
      ),
      _HeroPhase.running => (
        cancelRequested ? 'Зупиняюсь…' : 'Працюю…',
        cancelRequested
            ? 'Закінчу поточний рядок і зупинюсь. Зачекай секунду.'
            : '$filesDone з $queueLength ${_filesWord(queueLength)}. Не закривай вікно.',
        cancelRequested ? 'Стоп' : 'Зачекай',
      ),
      _HeroPhase.done => (
        'Готово!',
        'Сконвертував $queueLength ${_filesWord(queueLength)}. Можна забирати.',
        'Готово',
      ),
      _HeroPhase.error => (
        'Не все вийшло',
        '$filesError з $queueLength ${_filesWord(queueLength)} не змогли. Деталі — нижче.',
        'Помилка',
      ),
    };

    final HeroActionButton primary = switch (phase) {
      _HeroPhase.empty => HeroActionButton(
        label: 'Додати CSV',
        icon: CupertinoIcons.tray_arrow_down,
        onPressed: onAddFiles,
      ),
      _HeroPhase.ready => HeroActionButton(
        label: 'Поїхали',
        icon: CupertinoIcons.play_arrow_solid,
        onPressed: onStart,
      ),
      _HeroPhase.running => cancelRequested
          ? const HeroActionButton(
              label: 'Зупиняюсь…',
              loading: true,
            )
          : HeroActionButton(
              label: 'Зупинити',
              icon: CupertinoIcons.stop_fill,
              onPressed: onStop,
            ),
      _HeroPhase.done => HeroActionButton(
        label: 'Відкрити теку',
        icon: CupertinoIcons.folder_open,
        onPressed: onOpenOutput,
      ),
      _HeroPhase.error => HeroActionButton(
        label: 'Почати спочатку',
        icon: CupertinoIcons.arrow_counterclockwise,
        onPressed: onReset,
      ),
    };

    final Widget? secondary = switch (phase) {
      _HeroPhase.done => HeroGhostButton(
        label: 'Почати спочатку',
        icon: CupertinoIcons.arrow_counterclockwise,
        onPressed: onReset,
      ),
      _HeroPhase.error => HeroGhostButton(
        label: 'Відкрити теку',
        icon: CupertinoIcons.folder_open,
        onPressed: onOpenOutput,
      ),
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (copy.$3 != null)
          Text(
            copy.$3!.toUpperCase(),
            style: t.labelSmall.copyWith(
              color: CupertinoColors.white.withValues(alpha: 0.7),
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          copy.$1,
          style: t.headlineLarge.copyWith(
            color: CupertinoColors.white,
            fontSize: 30,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          copy.$2,
          style: t.bodyMedium.copyWith(
            color: CupertinoColors.white.withValues(alpha: 0.78),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            primary,
            ?secondary,
          ],
        ),
        const SizedBox(height: 14),
        _HeroOutputRow(
          label: outputLabel,
          isOverride: isOverrideOutput,
          onPick: onPickOutput,
          onReset: onResetOutput,
        ),
      ],
    );
  }

  static String _filesWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'файл';
    if (<int>[2, 3, 4].contains(n % 10) &&
        !<int>[12, 13, 14].contains(n % 100)) {
      return 'файли';
    }
    return 'файлів';
  }
}

class _HeroOutputRow extends StatelessWidget {
  const _HeroOutputRow({
    required this.label,
    required this.isOverride,
    required this.onPick,
    required this.onReset,
  });

  final String label;
  final bool isOverride;
  final VoidCallback onPick;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              CupertinoIcons.folder,
              size: 13,
              color: CupertinoColors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              'Зберігаю в:',
              style: t.labelSmall.copyWith(
                color: CupertinoColors.white.withValues(alpha: 0.7),
                letterSpacing: 0.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: t.labelMedium.copyWith(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          pressedOpacity: 0.55,
          onPressed: () {
            SoundService().tap();
            onPick();
          },
          child: Text(
            'змінити',
            style: t.labelSmall.copyWith(
              color: CupertinoColors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: CupertinoColors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
        if (isOverride && onReset != null)
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            pressedOpacity: 0.55,
            onPressed: () {
              SoundService().tap();
              onReset!();
            },
            child: Text(
              'скинути',
              style: t.labelSmall.copyWith(
                color: CupertinoColors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: CupertinoColors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// Stat strip
// =============================================================================

class _StatStrip extends StatelessWidget {
  const _StatStrip({
    required this.read,
    required this.written,
    required this.skipped,
    required this.failed,
    required this.chunks,
  });

  final int read;
  final int written;
  final int skipped;
  final int failed;
  final int chunks;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        // Five tiles in a single row need a bit more breathing room than four
        // did, otherwise labels start truncating on the small Mac. Below the
        // wide threshold we fall back to a wrap of two-per-row cards.
        final bool wide = box.maxWidth >= 880;
        final List<Widget> tiles = <Widget>[
          _StatTile(
            label: 'Прочитав',
            value: read,
            icon: CupertinoIcons.arrow_down_doc,
            accent: preset.heroEnd,
          ),
          _StatTile(
            label: 'Записав',
            value: written,
            icon: CupertinoIcons.checkmark_seal,
            accent: preset.successStrong,
          ),
          _StatTile(
            label: 'Пропустив',
            value: skipped,
            icon: CupertinoIcons.minus_circle,
            accent: preset.warningStrong,
          ),
          _StatTile(
            label: 'Не зміг',
            value: failed,
            icon: CupertinoIcons.exclamationmark_triangle,
            accent: preset.dangerStrong,
          ),
          _StatTile(
            label: 'Файлів на виході',
            value: chunks,
            icon: CupertinoIcons.square_stack_3d_up,
            accent: preset.infoStrong,
          ),
        ];
        if (wide) {
          return Row(
            children: <Widget>[
              for (int i = 0; i < tiles.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: tiles[i]),
              ],
            ],
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            for (final Widget tile in tiles)
              SizedBox(
                width: (box.maxWidth - 12) / 2,
                child: tile,
              ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;
    final AppThemePreset preset = context.preset;
    final NumberFormat n = NumberFormat.decimalPattern();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: preset.surfaceBase,
        borderRadius: BorderRadius.circular(AppTokens.cardCornerRadius),
        border: Border.all(color: preset.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: accent, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: t.labelSmall.copyWith(
                    letterSpacing: 0.8,
                    color: preset.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            n.format(value),
            style: t.headlineSmall.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: preset.textPrimary,
              height: 1,
              fontFeatures: const <FontFeature>[
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Queue
// =============================================================================

class _QueuedFile {
  const _QueuedFile({required this.path, this.sidecar});

  final String path;
  final ConverterConfig? sidecar;

  String get name => p.basename(path);
  String get parent => p.dirname(path);

  int get sizeBytes {
    try {
      return File(path).lengthSync();
    } on Object {
      return 0;
    }
  }

  String get sizeLabel {
    final int b = sizeBytes;
    return b == 0 ? '—' : _formatBytes(b);
  }
}

class _ConversionRunState {
  const _ConversionRunState({
    this.status = _RunStatus.queued,
    this.rowsRead = 0,
    this.rowsWritten = 0,
    this.rowsSkipped = 0,
    this.rowsFailed = 0,
    this.chunks = 0,
    this.bytesRead = 0,
    this.outputDirectory,
    this.lastChunkPath,
    this.errorMessage,
  });

  factory _ConversionRunState.queued() => const _ConversionRunState();

  final _RunStatus status;
  final int rowsRead;
  final int rowsWritten;
  final int rowsSkipped;
  final int rowsFailed;
  final int chunks;
  final int bytesRead;
  final String? outputDirectory;
  final String? lastChunkPath;
  final String? errorMessage;

  _ConversionRunState merge(ConversionEvent event) {
    return switch (event) {
      ConversionStarted() => copyWith(status: _RunStatus.running),
      ConversionChunkOpened(:final int chunkIndex, :final String chunkPath) =>
        copyWith(
          status: _RunStatus.running,
          chunks: chunkIndex,
          lastChunkPath: chunkPath,
        ),
      ConversionChunkClosed(:final String chunkPath) =>
        copyWith(lastChunkPath: chunkPath),
      ConversionProgress(
        :final int rowsRead,
        :final int rowsWritten,
        :final int rowsSkipped,
        :final int rowsFailed,
        :final int bytesRead,
      ) =>
        copyWith(
          status: _RunStatus.running,
          rowsRead: rowsRead,
          rowsWritten: rowsWritten,
          rowsSkipped: rowsSkipped,
          rowsFailed: rowsFailed,
          bytesRead: bytesRead,
        ),
      ConversionDone(
        :final String outputDirectory,
        :final int chunks,
        :final int rowsRead,
        :final int rowsWritten,
        :final int rowsSkipped,
        :final int rowsFailed,
        :final int bytesRead,
      ) =>
        copyWith(
          status: _RunStatus.done,
          outputDirectory: outputDirectory,
          chunks: chunks,
          rowsRead: rowsRead,
          rowsWritten: rowsWritten,
          rowsSkipped: rowsSkipped,
          rowsFailed: rowsFailed,
          bytesRead: bytesRead,
        ),
      ConversionError(:final String message) => copyWith(
        status: _RunStatus.error,
        errorMessage: message,
      ),
      ConversionCancelled(
        :final String outputDirectory,
        :final int chunks,
        :final int rowsRead,
        :final int rowsWritten,
        :final int rowsSkipped,
        :final int rowsFailed,
        :final int bytesRead,
      ) =>
        copyWith(
          status: _RunStatus.cancelled,
          outputDirectory: outputDirectory,
          chunks: chunks,
          rowsRead: rowsRead,
          rowsWritten: rowsWritten,
          rowsSkipped: rowsSkipped,
          rowsFailed: rowsFailed,
          bytesRead: bytesRead,
        ),
    };
  }

  _ConversionRunState copyWith({
    _RunStatus? status,
    int? rowsRead,
    int? rowsWritten,
    int? rowsSkipped,
    int? rowsFailed,
    int? chunks,
    int? bytesRead,
    String? outputDirectory,
    String? lastChunkPath,
    String? errorMessage,
  }) {
    return _ConversionRunState(
      status: status ?? this.status,
      rowsRead: rowsRead ?? this.rowsRead,
      rowsWritten: rowsWritten ?? this.rowsWritten,
      rowsSkipped: rowsSkipped ?? this.rowsSkipped,
      rowsFailed: rowsFailed ?? this.rowsFailed,
      chunks: chunks ?? this.chunks,
      bytesRead: bytesRead ?? this.bytesRead,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      lastChunkPath: lastChunkPath ?? this.lastChunkPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

enum _RunStatus { queued, running, done, error, cancelled }

class _QueueEmpty extends StatelessWidget {
  const _QueueEmpty();

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;
    final AppThemePreset preset = context.preset;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Row(
        children: <Widget>[
          Icon(
            CupertinoIcons.tray,
            color: preset.textMuted,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Тут поки порожньо', style: t.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Натисни «Додати» і обери CSV.',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.file,
    required this.runState,
    required this.running,
    required this.onRemove,
    required this.onApplySidecar,
    required this.onReveal,
  });

  final _QueuedFile file;
  final _ConversionRunState? runState;
  final bool running;
  final VoidCallback? onRemove;
  final VoidCallback? onApplySidecar;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;
    final AppThemePreset preset = context.preset;
    final _RunStatus status = runState?.status ?? _RunStatus.queued;
    final NumberFormat n = NumberFormat.decimalPattern();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              CupertinoIcons.doc_text,
              size: 18,
              color: preset.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    file.name,
                    style: t.titleSmall.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${file.sizeLabel} · ${file.parent}',
                    style: t.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StatusChip(status: status),
            if (status == _RunStatus.done ||
                status == _RunStatus.cancelled) ...<Widget>[
              const SizedBox(width: 6),
              AppIconButton(
                icon: CupertinoIcons.arrow_up_right_square,
                tooltip: 'Показати у Finder',
                onPressed: onReveal,
              ),
            ],
            if (onApplySidecar != null) ...<Widget>[
              const SizedBox(width: 6),
              AppIconButton(
                icon: CupertinoIcons.cloud_download,
                tooltip: 'Поряд знайдено config.txt — підвантажити',
                onPressed: onApplySidecar,
              ),
            ],
            if (onRemove != null)
              AppIconButton(
                icon: CupertinoIcons.xmark,
                tooltip: 'Прибрати',
                onPressed: onRemove,
              ),
          ],
        ),
        if (status == _RunStatus.running) ...<Widget>[
          const SizedBox(height: 10),
          LineProgress(
            gradientColors: <Color>[preset.heroMiddle, preset.heroEnd],
            trackColor: preset.borderSoft,
          ),
          const SizedBox(height: 6),
          Text(
            'Прочитав ${n.format(runState?.rowsRead ?? 0)} · '
            'Записав ${n.format(runState?.rowsWritten ?? 0)} · '
            'Файлів ${runState?.chunks ?? 0}',
            style: t.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ] else if ((status == _RunStatus.done ||
                status == _RunStatus.cancelled) &&
            runState != null) ...<Widget>[
          const SizedBox(height: 8),
          _DoneInline(state: runState!),
        ] else if (status == _RunStatus.error && runState != null) ...<Widget>[
          const SizedBox(height: 8),
          _ErrorInline(state: runState!),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _RunStatus status;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;
    final (Color bg, Color fg, String label, IconData icon) data =
        switch (status) {
          _RunStatus.queued => (
            preset.surfaceMuted,
            preset.textSecondary,
            'Чекає',
            CupertinoIcons.time,
          ),
          _RunStatus.running => (
            preset.infoSoft,
            preset.infoStrong,
            'Працюю',
            CupertinoIcons.arrow_2_circlepath,
          ),
          _RunStatus.done => (
            preset.successSoft,
            preset.successStrong,
            'Готово',
            CupertinoIcons.check_mark_circled,
          ),
          _RunStatus.error => (
            preset.dangerSoft,
            preset.dangerStrong,
            'Помилка',
            CupertinoIcons.exclamationmark_circle,
          ),
          _RunStatus.cancelled => (
            preset.warningSoft,
            preset.warningStrong,
            'Зупинено',
            CupertinoIcons.stop_circle,
          ),
        };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: data.$1,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: data.$2.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(data.$4, size: 14, color: data.$2),
          const SizedBox(width: 6),
          Text(
            data.$3,
            style: t.labelMedium.copyWith(
              color: data.$2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Flat one-liner shown beneath the file name when conversion is done.
/// No nested container — just a row of inline text on the card surface.
class _DoneInline extends StatelessWidget {
  const _DoneInline({required this.state});

  final _ConversionRunState state;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;
    final AppThemePreset preset = context.preset;
    final NumberFormat n = NumberFormat.decimalPattern();
    final TextStyle base = t.bodySmall.copyWith(color: preset.textSecondary);
    final TextStyle strong = t.bodySmall.copyWith(
      color: preset.textPrimary,
      fontWeight: FontWeight.w700,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _DoneStat(label: 'Прочитав', value: n.format(state.rowsRead),
            base: base, strong: strong),
        _DoneStat(label: 'Записав', value: n.format(state.rowsWritten),
            base: base, strong: strong),
        _DoneStat(label: 'Пропустив', value: n.format(state.rowsSkipped),
            base: base, strong: strong),
        if (state.rowsFailed > 0)
          _DoneStat(label: 'Не зміг', value: n.format(state.rowsFailed),
              base: base, strong: strong),
        _DoneStat(label: 'Файлів', value: '${state.chunks}',
            base: base, strong: strong),
      ],
    );
  }
}

class _DoneStat extends StatelessWidget {
  const _DoneStat({
    required this.label,
    required this.value,
    required this.base,
    required this.strong,
  });

  final String label;
  final String value;
  final TextStyle base;
  final TextStyle strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text('$label ', style: base),
        Text(value, style: strong),
      ],
    );
  }
}

/// Inline error line — single danger-colored row, no container.
class _ErrorInline extends StatelessWidget {
  const _ErrorInline({required this.state});

  final _ConversionRunState state;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;
    final AppThemePreset preset = context.preset;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          CupertinoIcons.exclamationmark_triangle_fill,
          size: 14,
          color: preset.dangerStrong,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            state.errorMessage ?? 'Невідома помилка',
            style: t.bodySmall.copyWith(color: preset.dangerStrong),
          ),
        ),
      ],
    );
  }
}

class _ActiveConfigSummary extends StatelessWidget {
  const _ActiveConfigSummary({required this.config});

  final ConverterConfig config;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;
    final AppThemePreset preset = context.preset;

    if (config.mappings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: <Widget>[
            Icon(
              CupertinoIcons.square_grid_2x2,
              color: preset.textMuted,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Колонки ще не задані. Зайди у вкладку «Колонки» і додай першу.',
                style: t.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    final List<String> facts = <String>[
      '${config.mappings.length} ${_columnsWord(config.mappings.length)}',
      if (config.dedupe.enabled && config.dedupe.column.isNotEmpty)
        'без повторів за «${config.dedupe.column}»'
      else if (config.dedupe.enabled)
        'без повторів',
      if (config.margins.isNotEmpty)
        '${config.margins.length} ${_rulesWord(config.margins.length)} націнки',
      'файли до ${config.maxFileSizeMb} МБ',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _CsvPreview(mappings: config.mappings),
        const SizedBox(height: 12),
        Text(
          facts.join(' · '),
          style: t.bodySmall.copyWith(color: preset.textSecondary),
        ),
      ],
    );
  }

  static String _columnsWord(int n) {
    final int mod10 = n % 10;
    final int mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'колонка';
    if (<int>[2, 3, 4].contains(mod10) && !<int>[12, 13, 14].contains(mod100)) {
      return 'колонки';
    }
    return 'колонок';
  }

  static String _rulesWord(int n) {
    final int mod10 = n % 10;
    final int mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'правило';
    if (<int>[2, 3, 4].contains(mod10) && !<int>[12, 13, 14].contains(mod100)) {
      return 'правила';
    }
    return 'правил';
  }
}

/// Excel-flavoured preview of the future CSV: header row with real column
/// names, a binding row showing where each value comes from, and a few
/// "data" rows of skeleton bars that fade out at the bottom.
///
/// Designed to be the visual centerpiece of the convert page — the user
/// should immediately see "this is what my output is going to look like".
class _CsvPreview extends StatelessWidget {
  const _CsvPreview({required this.mappings});

  final List<ColumnMapping> mappings;

  static const double _colWidth = 132;
  static const double _headerHeight = 34;
  static const double _bindingHeight = 30;
  static const double _rowHeight = 28;
  static const int _skeletonRows = 6;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;
    final bool isDark =
        CupertinoTheme.brightnessOf(context) == Brightness.dark;

    final Color cellBorder = preset.borderSoft;
    final Color headerBg = isDark
        ? preset.surfaceMuted.withValues(alpha: 0.6)
        : Color.lerp(preset.surfaceBase, preset.surfaceMuted, 0.65)!;
    final Color bindingBg = isDark
        ? const Color(0x14FFFFFF)
        : const Color(0x07000000);
    final Color altRowBg = isDark
        ? const Color(0x09FFFFFF)
        : const Color(0x05000000);

    Widget cellWrap({
      required Widget child,
      required bool last,
      Color? bg,
      double height = _rowHeight,
    }) {
      return Container(
        width: _colWidth,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            right: last
                ? BorderSide.none
                : BorderSide(color: cellBorder, width: 1),
            bottom: BorderSide(color: cellBorder, width: 1),
          ),
        ),
        child: child,
      );
    }

    final List<Widget> headerCells = <Widget>[
      for (int i = 0; i < mappings.length; i++)
        cellWrap(
          last: i == mappings.length - 1,
          bg: headerBg,
          height: _headerHeight,
          child: Row(
            children: <Widget>[
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: preset.heroEnd.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _colLetter(i),
                  style: t.labelSmall.copyWith(
                    color: preset.heroEnd,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mappings[i].outputColumn.isEmpty
                      ? 'col_${i + 1}'
                      : mappings[i].outputColumn,
                  style: t.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: preset.textPrimary,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
    ];

    final List<Widget> bindingCells = <Widget>[
      for (int i = 0; i < mappings.length; i++)
        cellWrap(
          last: i == mappings.length - 1,
          bg: bindingBg,
          height: _bindingHeight,
          child: _BindingChip(mapping: mappings[i]),
        ),
    ];

    final List<Widget> rows = <Widget>[
      Row(children: headerCells),
      Row(children: bindingCells),
      for (int r = 0; r < _skeletonRows; r++)
        Row(
          children: <Widget>[
            for (int i = 0; i < mappings.length; i++)
              cellWrap(
                last: i == mappings.length - 1,
                bg: r.isOdd ? altRowBg : null,
                child: _SkeletonBar(seed: r * 31 + i * 7),
              ),
          ],
        ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: preset.surfaceBase,
          border: Border.all(color: preset.borderSoft),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ShaderMask(
            shaderCallback: (Rect rect) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFF000000),
                  Color(0xFF000000),
                  Color(0x00000000),
                ],
                stops: <double>[0.0, 0.55, 1.0],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            ),
          ),
        ),
      ),
    );
  }

  static String _colLetter(int idx) {
    if (idx < 26) return String.fromCharCode(65 + idx);
    final int hi = (idx ~/ 26) - 1;
    final int lo = idx % 26;
    return '${String.fromCharCode(65 + hi)}${String.fromCharCode(65 + lo)}';
  }
}

/// Renders the "binding" line under the column header: either an arrow with
/// the source column name, or an "= value" pill for hardcoded mappings.
class _BindingChip extends StatelessWidget {
  const _BindingChip({required this.mapping});

  final ColumnMapping mapping;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;

    if (mapping.kind == ColumnMappingKind.hardcoded) {
      final String? raw = mapping.hardcodedValue;
      final String value =
          raw == null || raw.isEmpty ? '—' : '"$raw"';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '=',
            style: t.labelSmall.copyWith(
              color: preset.warningStrong,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              style: t.labelSmall.copyWith(
                color: preset.textSecondary,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final String src =
        (mapping.sourceColumn ?? '').isEmpty ? '?' : mapping.sourceColumn!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(CupertinoIcons.arrow_left, size: 11, color: preset.heroEnd),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            src,
            style: t.labelSmall.copyWith(
              color: preset.heroEnd,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Tiny rounded bar that stands in for "data goes here". Width pseudo-random
/// per [seed] so the table looks lived-in instead of robotic.
class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.seed});

  final int seed;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final double w = 36 + (seed.abs() % 56).toDouble();
    return Container(
      height: 8,
      width: w,
      decoration: BoxDecoration(
        color: preset.textMuted.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const List<String> units = <String>['KB', 'MB', 'GB', 'TB'];
  double value = bytes / 1024;
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
}
