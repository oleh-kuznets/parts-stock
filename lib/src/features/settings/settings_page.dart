import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../app/app_state.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme_preset.dart';
import '../../core/models/converter_config.dart';
import '../../core/services/file_reveal.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_dialogs.dart';
import '../../shared/widgets/app_form_rows.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/hero_panel.dart';
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
      confirmButtonText: 'Обрати',
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
      'Зберіг у ${location.path}',
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
      AppToast.show(context, 'Підвантажив конфіг', tone: AppToastTone.success);
    } on Object catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        'Не зміг прочитати конфіг: $error',
        tone: AppToastTone.danger,
      );
    }
  }

  Future<void> _resetDefaults() async {
    final bool? ok = await showAppConfirm(
      context,
      title: 'Скинути все?',
      message:
          'Твої колонки, націнки та налаштування заміняться на стандартні. '
          'Назад уже не повернути.',
      confirmLabel: 'Скинути',
      destructive: true,
    );
    if (ok != true) return;
    await widget.appState.resetToDefaults();
    if (!mounted) return;
    AppToast.show(context, 'Скинуто', tone: AppToastTone.success);
  }

  @override
  Widget build(BuildContext context) {
    final ConverterConfig config = widget.appState.config;
    return PageScaffold(
      children: <Widget>[
        FeatureHero(
          compact: true,
          icon: CupertinoIcons.gear_alt,
          eyebrow: 'Налаштування',
          title: 'Налаштуй під себе',
          subtitle:
              'Розмір файлів, тема, тека для виходу і звуки. Все зберігається '
              'одразу — кнопки «Зберегти» немає.',
          stats: <Widget>[
            HeroStatChip(
              label: 'Розмір',
              value: '${config.maxFileSizeMb} МБ',
              icon: CupertinoIcons.cube_box,
            ),
            HeroStatChip(
              label: 'Тема',
              value: switch (widget.appState.themeMode) {
                AppThemeMode.system => 'Авто',
                AppThemeMode.light => 'Світла',
                AppThemeMode.dark => 'Темна',
              },
              icon: CupertinoIcons.moon_stars,
            ),
            HeroStatChip(
              label: 'Звуки',
              value: widget.appState.uiSoundsEnabled ? 'увімк.' : 'вимк.',
              icon: widget.appState.uiSoundsEnabled
                  ? CupertinoIcons.speaker_2
                  : CupertinoIcons.speaker_slash,
              tone: widget.appState.uiSoundsEnabled
                  ? HeroChipTone.positive
                  : HeroChipTone.neutral,
            ),
            HeroStatChip(
              label: 'Тека',
              value: widget.appState.outputDirectoryOverride == null
                  ? 'дефолт'
                  : 'своя',
              icon: CupertinoIcons.folder,
              tone: widget.appState.outputDirectoryOverride == null
                  ? HeroChipTone.neutral
                  : HeroChipTone.positive,
            ),
          ],
          primary: HeroActionButton(
            compact: true,
            label: 'Зберегти у файл',
            icon: CupertinoIcons.arrow_up_doc,
            onPressed: _exportConfig,
          ),
          secondary: HeroGhostButton(
            compact: true,
            label: 'Підвантажити…',
            icon: CupertinoIcons.arrow_down_doc,
            onPressed: _importConfig,
          ),
        ),
        SectionCard(
          compact: true,
          title: 'Максимальний розмір файлу',
          subtitle:
              'Якщо готовий файл більший за ліміт — поб’ємо на `_part1`, `_part2`, …',
          leading: const SectionLeadingIcon(
            icon: CupertinoIcons.cube_box,
            compact: true,
          ),
          child: SizedBox(
            width: 220,
            child: AppTextField(
              label: 'Скільки МБ максимум',
              controller: _chunkController,
              keyboardType: TextInputType.number,
              suffix: Text(
                'МБ',
                style: context.appText.bodyMedium.copyWith(
                  color: context.preset.textMuted,
                ),
              ),
              onChanged: (String value) {
                final int? parsed = int.tryParse(value.trim());
                if (parsed != null && parsed > 0) {
                  widget.appState.updateChunkSizeMb(parsed);
                }
              },
            ),
          ),
        ),
        SectionCard(
          compact: true,
          title: 'Назва готових файлів',
          subtitle:
              'Цей текст приклеїться до назви вхідного. Приклад: `land_rover{суфікс}_part1.csv`.',
          leading: const SectionLeadingIcon(
            icon: CupertinoIcons.tag_circle,
            compact: true,
          ),
          child: AppTextField(
            label: 'Що дописати',
            placeholder: '_pricelist',
            controller: _suffixController,
            onChanged: widget.appState.updateOutputBaseSuffix,
          ),
        ),
        SectionCard(
          compact: true,
          title: 'Куди зберігати',
          subtitle:
              'За замовчуванням — папка «output» поряд із програмою. Можна обрати свою.',
          leading: const SectionLeadingIcon(
            icon: CupertinoIcons.folder,
            compact: true,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _OutputPathInfo(
                effectivePath: widget.appState.effectiveOutputPath,
                isOverride: widget.appState.outputDirectoryOverride != null,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  AppButton.secondary(
                    icon: CupertinoIcons.folder_open,
                    label: 'Обрати теку…',
                    onPressed: _pickOutputDir,
                    compact: true,
                  ),
                  if (widget.appState.outputDirectoryOverride != null)
                    AppButton.link(
                      icon: CupertinoIcons.xmark_circle,
                      label: 'Повернути за замовчуванням',
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
          compact: true,
          title: 'Тема',
          leading: const SectionLeadingIcon(
            icon: CupertinoIcons.moon_stars,
            compact: true,
          ),
          child: AppSegmented<AppThemeMode>(
            value: widget.appState.themeMode,
            onChanged: widget.appState.setThemeMode,
            children: const <AppThemeMode, Widget>{
              AppThemeMode.system: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text('Системна'),
              ),
              AppThemeMode.light: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text('Світла'),
              ),
              AppThemeMode.dark: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text('Темна'),
              ),
            },
          ),
        ),
        SectionCard(
          compact: true,
          title: 'Звуки',
          subtitle:
              'Тихі сигнали на кліки, повідомлення та завершення.',
          leading: const SectionLeadingIcon(
            icon: CupertinoIcons.speaker_2,
            compact: true,
          ),
          child: AppSwitchRow(
            title: 'Звуки інтерфейсу',
            subtitle: 'Вимкни, якщо хочеш тиху роботу.',
            value: widget.appState.uiSoundsEnabled,
            onChanged: widget.appState.setUiSoundsEnabled,
          ),
        ),
        SectionCard(
          compact: true,
          title: 'Активний конфіг',
          subtitle:
              'Тут лежить файл `config.json`. Можна скинути все до стандартного '
              'стану.',
          leading: const SectionLeadingIcon(
            icon: CupertinoIcons.doc_text,
            compact: true,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_storagePath != null)
                _StoragePathRow(storagePath: _storagePath!),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton.danger(
                  compact: true,
                  icon: CupertinoIcons.refresh,
                  label: 'Скинути все',
                  onPressed: _resetDefaults,
                ),
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
    return Row(
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
                isOverride ? 'Своя тека' : 'За замовчуванням',
                style: t.labelSmall.copyWith(
                  color: preset.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                effectivePath,
                style: t.bodyMedium.copyWith(color: preset.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        AppIconButton(
          icon: CupertinoIcons.arrow_up_right_square,
          tooltip: 'Відкрити у Finder',
          onPressed: () async {
            await FileReveal.openDirectory(effectivePath);
          },
        ),
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
    return Row(
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
                'Конфіг лежить тут',
                style: t.labelSmall.copyWith(
                  color: preset.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                p.join(storagePath, 'config.json'),
                style: t.bodyMedium.copyWith(color: preset.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        AppIconButton(
          icon: CupertinoIcons.arrow_up_right_square,
          tooltip: 'Відкрити у Finder',
          onPressed: () async {
            await FileReveal.openDirectory(storagePath);
          },
        ),
      ],
    );
  }
}
