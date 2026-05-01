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
import '../../core/services/sound_service.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/page_scaffold.dart';
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
  StreamSubscription<ConversionEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onState);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onState);
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
      dialogTitle: 'Виберіть CSV файли',
      lockParentWindow: true,
    );
    if (result == null) return;
    final List<_QueuedFile> next = <_QueuedFile>[];
    for (final PlatformFile picked in result.files) {
      final String? path = picked.path;
      if (path == null) continue;
      if (_queue.any((_QueuedFile q) => q.path == path)) continue;
      final ConverterConfig? sidecar =
          await widget.appState.storage.tryLoadSidecar(path);
      next.add(_QueuedFile(path: path, sidecar: sidecar));
    }
    if (next.isEmpty) return;
    SoundService().drop();
    setState(() => _queue.addAll(next));
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
      'config.txt застосовано до активних налаштувань',
      tone: AppToastTone.success,
    );
  }

  Future<void> _runConversion() async {
    if (_queue.isEmpty || _running) return;
    final CsvConverter converter = CsvConverter();
    final ConverterConfig snapshot = widget.appState.config;

    setState(() {
      _running = true;
      for (final _QueuedFile q in _queue) {
        _runStates[q.path] = _ConversionRunState.queued();
      }
    });

    bool encounteredError = false;
    final Stream<ConversionEvent> stream = converter.convertAll(
      inputPaths: _queue.map((_QueuedFile q) => q.path).toList(growable: false),
      config: snapshot,
      outputDirectoryOverride: widget.appState.outputDirectoryOverride,
    );

    await _subscription?.cancel();
    _subscription = stream.listen(
      (ConversionEvent event) {
        if (event is ConversionError) {
          encounteredError = true;
        }
        setState(() {
          _runStates[event.inputPath] =
              (_runStates[event.inputPath] ?? _ConversionRunState.queued())
                  .merge(event);
        });
      },
      onError: (Object error, StackTrace stack) {
        encounteredError = true;
        if (!mounted) return;
        AppToast.show(context, 'Помилка: $error', tone: AppToastTone.danger);
      },
      onDone: () {
        if (!mounted) {
          return;
        }
        setState(() => _running = false);
        if (!encounteredError) {
          SoundService().tourCompletion();
          AppToast.show(
            context,
            'Готово · ${_queue.length} файл(ів) сконвертовано',
            tone: AppToastTone.success,
            silent: true,
          );
        }
      },
      cancelOnError: false,
    );
  }

  String _outputDirLabel() {
    final String? override = widget.appState.outputDirectoryOverride;
    if (override == null) {
      return 'Біля екзешніка · ${defaultExecutableOutputPath()}';
    }
    return 'Тека: $override';
  }

  @override
  Widget build(BuildContext context) {
    final ConverterConfig config = widget.appState.config;
    return PageScaffold(
      title: 'Конвертер',
      subtitle:
          'Виберіть один або декілька CSV. Кожен буде оброблено з активною конфігурацією.',
      actions: <Widget>[
        AppButton.secondary(
          icon: CupertinoIcons.folder,
          label: widget.appState.outputDirectoryOverride == null
              ? 'Тека: за замовчуванням'
              : 'Тека: ${p.basename(widget.appState.outputDirectoryOverride!)}',
          onPressed: _pickOutputDir,
          compact: true,
        ),
        AppButton.primary(
          icon: _running ? null : CupertinoIcons.play_arrow_solid,
          label: _running ? 'Триває…' : 'Запустити (${_queue.length})',
          onPressed: _running || _queue.isEmpty ? null : _runConversion,
          loading: _running,
        ),
      ],
      children: <Widget>[
        SectionCard(
          title: 'Файли в черзі',
          subtitle:
              'Підтримується тільки .csv. Файл із сусіднім config.txt можна застосувати в один клік.',
          leading: const SectionLeadingIcon(icon: CupertinoIcons.tray_arrow_down),
          trailing: Wrap(
            spacing: 8,
            children: <Widget>[
              if (_queue.isNotEmpty)
                AppButton.plain(
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
          child: _queue.isEmpty
              ? EmptyState(
                  icon: CupertinoIcons.cloud_upload,
                  title: 'Немає вхідних файлів',
                  message: 'Натисніть «Додати», щоб вибрати один або декілька CSV.',
                  action: AppButton.primary(
                    icon: CupertinoIcons.doc_text,
                    label: 'Вибрати CSV…',
                    onPressed: _pickFiles,
                  ),
                )
              : Column(
                  children: <Widget>[
                    for (int i = 0; i < _queue.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(height: 10),
                      _QueueRow(
                        file: _queue[i],
                        runState: _runStates[_queue[i].path],
                        onRemove: _running
                            ? null
                            : () => _removeFromQueue(_queue[i]),
                        onApplySidecar: _queue[i].sidecar == null
                            ? null
                            : () => _applySidecar(_queue[i]),
                      ),
                    ],
                  ],
                ),
        ),
        SectionCard(
          title: 'Куди писати',
          subtitle: _outputDirLabel(),
          leading: const SectionLeadingIcon(icon: CupertinoIcons.tray_arrow_up),
          trailing: widget.appState.outputDirectoryOverride == null
              ? null
              : AppButton.plain(
                  icon: CupertinoIcons.arrow_uturn_left,
                  label: 'Скинути',
                  onPressed: () =>
                      widget.appState.setOutputDirectoryOverride(null),
                  compact: true,
                ),
          child: Text(
            'За замовчуванням файли потраплять у тeку «output», що лежить поряд з екзешніком апки. '
            'Можна перевизначити — наприклад, на загальну мережеву теку.',
            style: context.appText.bodyMedium,
          ),
        ),
        SectionCard(
          title: 'Що буде у вихідних файлах',
          leading: const SectionLeadingIcon(icon: CupertinoIcons.eye),
          child: _ActiveConfigSummary(config: config),
        ),
      ],
    );
  }
}

class _QueuedFile {
  const _QueuedFile({required this.path, this.sidecar});

  final String path;
  final ConverterConfig? sidecar;

  String get name => p.basename(path);
  String get parent => p.dirname(path);

  String get sizeLabel {
    try {
      final int bytes = File(path).lengthSync();
      return _formatBytes(bytes);
    } on Object {
      return '—';
    }
  }
}

class _ConversionRunState {
  const _ConversionRunState({
    this.status = _RunStatus.queued,
    this.rowsRead = 0,
    this.rowsWritten = 0,
    this.rowsSkipped = 0,
    this.chunks = 0,
    this.outputDirectory,
    this.lastChunkPath,
    this.errorMessage,
  });

  factory _ConversionRunState.queued() => const _ConversionRunState();

  final _RunStatus status;
  final int rowsRead;
  final int rowsWritten;
  final int rowsSkipped;
  final int chunks;
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
      ) =>
        copyWith(
          status: _RunStatus.running,
          rowsRead: rowsRead,
          rowsWritten: rowsWritten,
          rowsSkipped: rowsSkipped,
        ),
      ConversionDone(
        :final String outputDirectory,
        :final int chunks,
        :final int rowsRead,
        :final int rowsWritten,
        :final int rowsSkipped,
      ) =>
        copyWith(
          status: _RunStatus.done,
          outputDirectory: outputDirectory,
          chunks: chunks,
          rowsRead: rowsRead,
          rowsWritten: rowsWritten,
          rowsSkipped: rowsSkipped,
        ),
      ConversionError(:final String message) => copyWith(
        status: _RunStatus.error,
        errorMessage: message,
      ),
    };
  }

  _ConversionRunState copyWith({
    _RunStatus? status,
    int? rowsRead,
    int? rowsWritten,
    int? rowsSkipped,
    int? chunks,
    String? outputDirectory,
    String? lastChunkPath,
    String? errorMessage,
  }) {
    return _ConversionRunState(
      status: status ?? this.status,
      rowsRead: rowsRead ?? this.rowsRead,
      rowsWritten: rowsWritten ?? this.rowsWritten,
      rowsSkipped: rowsSkipped ?? this.rowsSkipped,
      chunks: chunks ?? this.chunks,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      lastChunkPath: lastChunkPath ?? this.lastChunkPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

enum _RunStatus { queued, running, done, error }

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.file,
    required this.runState,
    required this.onRemove,
    required this.onApplySidecar,
  });

  final _QueuedFile file;
  final _ConversionRunState? runState;
  final VoidCallback? onRemove;
  final VoidCallback? onApplySidecar;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;
    final AppThemePreset preset = context.preset;
    final Brightness brightness = CupertinoTheme.brightnessOf(context);
    final _RunStatus status = runState?.status ?? _RunStatus.queued;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: preset.surfaceMuted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTokens.fieldCornerRadius),
        border: Border.all(color: preset.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: preset.iconAccentTileBackground(
                    preset.heroEnd,
                    brightness,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  CupertinoIcons.doc_text,
                  size: 18,
                  color: preset.heroEnd,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      file.name,
                      style: t.titleSmall.copyWith(fontWeight: FontWeight.w700),
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
              if (onApplySidecar != null) ...<Widget>[
                const SizedBox(width: 6),
                AppIconButton(
                  icon: CupertinoIcons.cloud_download,
                  tooltip: 'Поряд знайдено config.txt — застосувати',
                  onPressed: onApplySidecar,
                ),
              ],
              if (onRemove != null)
                AppIconButton(
                  icon: CupertinoIcons.xmark,
                  tooltip: 'Прибрати з черги',
                  onPressed: onRemove,
                ),
            ],
          ),
          if (runState != null && status != _RunStatus.queued) ...<Widget>[
            const SizedBox(height: 12),
            _RunStateDetails(state: runState!),
          ],
        ],
      ),
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
            'У черзі',
            CupertinoIcons.time,
          ),
          _RunStatus.running => (
            preset.infoSoft,
            preset.infoStrong,
            'Триває',
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

class _RunStateDetails extends StatelessWidget {
  const _RunStateDetails({required this.state});

  final _ConversionRunState state;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;
    final AppThemePreset preset = context.preset;
    final NumberFormat n = NumberFormat.decimalPattern();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: preset.surfaceBase,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: preset.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: <Widget>[
              _StatPair(label: 'Прочитано', value: n.format(state.rowsRead)),
              _StatPair(label: 'Записано', value: n.format(state.rowsWritten)),
              _StatPair(label: 'Пропущено', value: n.format(state.rowsSkipped)),
              _StatPair(label: 'Частин', value: '${state.chunks}'),
            ],
          ),
          if (state.lastChunkPath != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Останній файл: ${state.lastChunkPath}',
              style: t.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (state.errorMessage != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              state.errorMessage!,
              style: t.bodySmall.copyWith(color: preset.dangerStrong),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatPair extends StatelessWidget {
  const _StatPair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: t.labelSmall.copyWith(letterSpacing: 0.6),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: t.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SummaryRow(label: 'Колонок у виході', value: '${config.mappings.length}'),
        _SummaryRow(
          label: 'Цінова колонка',
          value:
              '${config.priceConfig.sourceColumn} → ${config.priceConfig.outputColumn}',
        ),
        _SummaryRow(
          label: 'Дедуплікація',
          value: config.dedupe.enabled
              ? 'за «${config.dedupe.column}»'
              : 'вимкнено',
        ),
        _SummaryRow(label: 'Правил націнки', value: '${config.margins.length}'),
        _SummaryRow(
          label: 'Макс. розмір частини',
          value: '${config.maxFileSizeMb} МБ',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final ColumnMapping m in config.mappings)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: preset.infoSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: preset.infoStrong.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  m.kind == ColumnMappingKind.hardcoded
                      ? '${m.outputColumn} ⤴ "${m.hardcodedValue ?? ''}"'
                      : '${m.outputColumn} ← ${m.sourceColumn ?? '?'}',
                  style: t.labelMedium.copyWith(
                    color: preset.infoStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;
    final AppThemePreset preset = context.preset;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: t.bodyMedium)),
          Text(
            value,
            style: t.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: preset.textPrimary,
            ),
          ),
        ],
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
