import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../app/app_state.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme_preset.dart';
import '../../core/models/converter_config.dart';
import '../../core/services/csv_converter.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_dialogs.dart';
import '../../shared/widgets/app_form_rows.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/section_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _chunkController;
  late TextEditingController _suffixController;
  String? _storagePath;

  @override
  void initState() {
    super.initState();
    final ConverterConfig active = widget.appState.config;
    _chunkController = TextEditingController(
      text: active.maxFileSizeMb.toString(),
    );
    _suffixController = TextEditingController(text: active.outputBaseSuffix);
    widget.appState.addListener(_resync);
    widget.appState.storage.resolvedDirPath().then((String value) {
      if (mounted) setState(() => _storagePath = value);
    });
  }

  @override
  void dispose() {
    widget.appState.removeListener(_resync);
    _chunkController.dispose();
    _suffixController.dispose();
    super.dispose();
  }

  void _resync() {
    final ConverterConfig active = widget.appState.config;
    if (_chunkController.text != active.maxFileSizeMb.toString()) {
      _chunkController.text = active.maxFileSizeMb.toString();
    }
    if (_suffixController.text != active.outputBaseSuffix) {
      _suffixController.text = active.outputBaseSuffix;
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickOutputDir() async {
    final String? selected = await getDirectoryPath(
      confirmButtonText: 'Вибрати',
    );
    if (selected == null) return;
    widget.appState.setOutputDirectoryOverride(selected);
  }

  Future<void> _exportConfig() async {
    final ConverterConfig active = widget.appState.config;
    const XTypeGroup group = XTypeGroup(
      label: 'Config text',
      extensions: <String>['txt', 'json'],
    );
    final FileSaveLocation? location = await getSaveLocation(
      acceptedTypeGroups: const <XTypeGroup>[group],
      suggestedName: 'config.txt',
    );
    if (location == null) return;
    await widget.appState.storage.exportTo(location.path, active);
    if (!mounted) return;
    AppToast.show(
      context,
      'Експортовано: ${location.path}',
      tone: AppToastTone.success,
    );
  }

  Future<void> _importConfig() async {
    const XTypeGroup group = XTypeGroup(
      label: 'Config',
      extensions: <String>['txt', 'json'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[group],
    );
    if (file == null) return;
    try {
      final String raw = await File(file.path).readAsString();
      final ConverterConfig next = ConverterConfig.fromJsonString(raw);
      await widget.appState.applySidecar(next);
      if (!mounted) return;
      AppToast.show(context, 'Конфіг імпортовано', tone: AppToastTone.success);
    } on Object catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        'Не вдалося прочитати конфіг: $error',
        tone: AppToastTone.danger,
      );
    }
  }

  Future<void> _resetDefaults() async {
    final bool? ok = await showAppConfirm(
      context,
      title: 'Скинути до стандартних?',
      message:
          'Усі ваші мапінги, націнки та налаштування буде замінено на стандартні значення.',
      confirmLabel: 'Скинути',
      destructive: true,
    );
    if (ok != true) return;
    await widget.appState.resetToDefaults();
    if (!mounted) return;
    AppToast.show(context, 'Конфіг скинуто', tone: AppToastTone.success);
  }

  @override
  Widget build(BuildContext context) {
    final ConverterConfig config = widget.appState.config;
    return PageScaffold(
      title: 'Налаштування',
      subtitle:
          'Розмір частини, тема, тека за замовчуванням і робота з файлом config.txt.',
      children: <Widget>[
        SectionCard(
          title: 'Чанк-сайз (макс. розмір частини)',
          subtitle:
              'Якщо вихідний CSV перевищує цей ліміт — буде створено `_part1`, `_part2`, …',
          leading: const SectionLeadingIcon(icon: CupertinoIcons.cube_box),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              SizedBox(
                width: 240,
                child: AppTextField(
                  label: 'Макс. розмір частини, МБ',
                  controller: _chunkController,
                  keyboardType: TextInputType.number,
                  suffix: Text(
                    'МБ',
                    style: context.appText.bodyMedium.copyWith(
                      color: context.preset.textMuted,
                    ),
                  ),
                  onSubmitted: (String value) {
                    final int parsed =
                        int.tryParse(value) ?? config.maxFileSizeMb;
                    widget.appState.updateChunkSizeMb(parsed);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: AppButton.primary(
                  icon: CupertinoIcons.checkmark_alt,
                  label: 'Застосувати',
                  onPressed: () {
                    final int parsed = int.tryParse(_chunkController.text) ??
                        config.maxFileSizeMb;
                    widget.appState.updateChunkSizeMb(parsed);
                  },
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Іменування вихідних файлів',
          subtitle:
              'Суфікс додається до базової назви вхідного CSV. Приклад: `land_rover{суфікс}_part1.csv`.',
          leading: const SectionLeadingIcon(icon: CupertinoIcons.tag_circle),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  label: 'Суфікс',
                  placeholder: '_pricelist',
                  controller: _suffixController,
                  onSubmitted: (String value) =>
                      widget.appState.updateOutputBaseSuffix(value),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: AppButton.primary(
                  icon: CupertinoIcons.checkmark_alt,
                  label: 'Застосувати',
                  onPressed: () => widget.appState.updateOutputBaseSuffix(
                    _suffixController.text,
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Тека для виходу',
          subtitle:
              'За замовчуванням — папка «output» поряд з екзешніком апки. Можна перевизначити.',
          leading: const SectionLeadingIcon(icon: CupertinoIcons.folder),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _OutputPathInfo(
                effectivePath: widget.appState.outputDirectoryOverride ??
                    defaultExecutableOutputPath(),
                isOverride: widget.appState.outputDirectoryOverride != null,
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  AppButton.secondary(
                    icon: CupertinoIcons.folder_open,
                    label: 'Вибрати теку…',
                    onPressed: _pickOutputDir,
                    compact: true,
                  ),
                  const SizedBox(width: 10),
                  if (widget.appState.outputDirectoryOverride != null)
                    AppButton.plain(
                      icon: CupertinoIcons.xmark_circle,
                      label: 'Скинути до дефолту',
                      onPressed: () =>
                          widget.appState.setOutputDirectoryOverride(null),
                      compact: true,
                    ),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Тема',
          leading: const SectionLeadingIcon(icon: CupertinoIcons.moon_stars),
          child: AppSegmented<AppThemeMode>(
            value: widget.appState.themeMode,
            onChanged: widget.appState.setThemeMode,
            children: const <AppThemeMode, Widget>{
              AppThemeMode.system: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text('Системна'),
              ),
              AppThemeMode.light: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text('Світла'),
              ),
              AppThemeMode.dark: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text('Темна'),
              ),
            },
          ),
        ),
        SectionCard(
          title: 'Звуки інтерфейсу',
          subtitle:
              'Тихі сигнали для тапів, тостів і завершення конвертації. '
              'Той самий набір звуків, що в WiseWater Connect.',
          leading: const SectionLeadingIcon(icon: CupertinoIcons.speaker_2),
          child: AppSwitchRow(
            title: 'Грати UI-звуки',
            subtitle: 'Вимкніть, якщо хочете тиху роботу.',
            value: widget.appState.uiSoundsEnabled,
            onChanged: widget.appState.setUiSoundsEnabled,
          ),
        ),
        SectionCard(
          title: 'Файл config.txt',
          subtitle:
              'Експортуйте конфіг і покладіть `config.txt` поряд із CSV — апка автоматично запропонує його застосувати.',
          leading: const SectionLeadingIcon(icon: CupertinoIcons.doc_text),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_storagePath != null) _StoragePathRow(storagePath: _storagePath!),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  AppButton.primary(
                    icon: CupertinoIcons.arrow_up_doc,
                    label: 'Експорт у файл…',
                    onPressed: _exportConfig,
                  ),
                  AppButton.secondary(
                    icon: CupertinoIcons.arrow_down_doc,
                    label: 'Імпорт з файлу…',
                    onPressed: _importConfig,
                  ),
                  AppButton.plain(
                    icon: CupertinoIcons.refresh,
                    label: 'Скинути до стандартних',
                    onPressed: _resetDefaults,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OutputPathInfo extends StatelessWidget {
  const _OutputPathInfo({
    required this.effectivePath,
    required this.isOverride,
  });

  final String effectivePath;
  final bool isOverride;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: preset.surfaceMuted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: preset.borderSoft),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isOverride
                ? CupertinoIcons.folder_fill_badge_person_crop
                : CupertinoIcons.folder_fill,
            size: 18,
            color: preset.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isOverride ? 'Перевизначено' : 'За замовчуванням',
                  style: t.labelMedium.copyWith(color: preset.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  effectivePath,
                  style: t.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppIconButton(
            icon: CupertinoIcons.doc_on_clipboard,
            tooltip: 'Скопіювати шлях',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: effectivePath));
              if (!context.mounted) return;
              AppToast.show(context, 'Шлях скопійовано');
            },
          ),
        ],
      ),
    );
  }
}

class _StoragePathRow extends StatelessWidget {
  const _StoragePathRow({required this.storagePath});

  final String storagePath;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: preset.surfaceMuted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: preset.borderSoft),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            CupertinoIcons.folder_fill_badge_plus,
            size: 18,
            color: preset.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Тека з активним конфігом',
                  style: t.labelMedium.copyWith(color: preset.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  p.join(storagePath, 'config.json'),
                  style: t.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
