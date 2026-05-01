import 'package:flutter/cupertino.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_theme_preset.dart';
import '../../core/models/converter_config.dart';
import '../../core/services/sound_service.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_form_rows.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/section_card.dart';

class MappingsPage extends StatefulWidget {
  const MappingsPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<MappingsPage> createState() => _MappingsPageState();
}

class _MappingsPageState extends State<MappingsPage> {
  late List<ColumnMapping> _draft;
  late PriceColumnConfig _price;
  late DedupeConfig _dedupe;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_resync);
    _resync();
  }

  @override
  void dispose() {
    widget.appState.removeListener(_resync);
    super.dispose();
  }

  void _resync() {
    if (_dirty) return;
    final ConverterConfig active = widget.appState.config;
    setState(() {
      _draft = List<ColumnMapping>.of(active.mappings);
      _price = active.priceConfig;
      _dedupe = active.dedupe;
    });
  }

  void _markDirty(VoidCallback mutator) {
    setState(() {
      mutator();
      _dirty = true;
    });
  }

  Future<void> _save() async {
    await widget.appState.replaceMappings(_draft);
    await widget.appState.updatePriceConfig(_price);
    await widget.appState.updateDedupe(_dedupe);
    if (!mounted) return;
    setState(() => _dirty = false);
    SoundService().saved();
    AppToast.show(
      context,
      'Структуру збережено',
      tone: AppToastTone.success,
      silent: true,
    );
  }

  void _addRow() {
    _markDirty(() {
      _draft.add(
        const ColumnMapping(
          outputColumn: '',
          kind: ColumnMappingKind.source,
          sourceColumn: '',
        ),
      );
    });
  }

  void _removeRow(int index) {
    _markDirty(() => _draft.removeAt(index));
  }

  void _moveUp(int index) {
    if (index == 0) return;
    _markDirty(() {
      final ColumnMapping moved = _draft.removeAt(index);
      _draft.insert(index - 1, moved);
    });
  }

  void _moveDown(int index) {
    if (index >= _draft.length - 1) return;
    _markDirty(() {
      final ColumnMapping moved = _draft.removeAt(index);
      _draft.insert(index + 1, moved);
    });
  }

  void _updateRow(int index, ColumnMapping next) {
    _markDirty(() => _draft[index] = next);
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Структура колонок',
      subtitle:
          'Опишіть, які колонки буде у вихідному CSV: тягнути зі вхідного або жорстко прописати.',
      actions: <Widget>[
        AppButton.secondary(
          icon: CupertinoIcons.arrow_uturn_left,
          label: 'Скасувати',
          onPressed: _dirty
              ? () {
                  setState(() => _dirty = false);
                  _resync();
                }
              : null,
          compact: true,
        ),
        AppButton.primary(
          icon: CupertinoIcons.checkmark_alt,
          label: 'Зберегти',
          onPressed: _dirty ? _save : null,
        ),
      ],
      children: <Widget>[
        SectionCard(
          title: 'Вихідні колонки',
          subtitle:
              'Порядок у списку — порядок у CSV. Стрілками поряд із рядком переставляйте місцями.',
          leading:
              const SectionLeadingIcon(icon: CupertinoIcons.square_grid_2x2),
          trailing: AppButton.secondary(
            icon: CupertinoIcons.add,
            label: 'Додати колонку',
            onPressed: _addRow,
            compact: true,
          ),
          child: _draft.isEmpty
              ? EmptyState(
                  icon: CupertinoIcons.square_grid_2x2,
                  title: 'Поки немає колонок',
                  message: 'Додайте першу колонку для вихідного CSV.',
                  action: AppButton.primary(
                    icon: CupertinoIcons.add,
                    label: 'Додати',
                    onPressed: _addRow,
                  ),
                )
              : Column(
                  children: <Widget>[
                    for (int i = 0; i < _draft.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(height: 10),
                      _MappingRow(
                        key: ValueKey<int>(i),
                        index: i,
                        total: _draft.length,
                        mapping: _draft[i],
                        onChanged: (ColumnMapping next) => _updateRow(i, next),
                        onRemove: () => _removeRow(i),
                        onMoveUp: () => _moveUp(i),
                        onMoveDown: () => _moveDown(i),
                      ),
                    ],
                  ],
                ),
        ),
        SectionCard(
          title: 'Вхідна цінова колонка',
          subtitle:
              'З якої колонки брати ціну і яку вихідну колонку нею заповнювати після націнки.',
          leading: const SectionLeadingIcon(icon: CupertinoIcons.tag),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      key: ValueKey<String>('price-src-${_price.sourceColumn}'),
                      label: 'Колонка з ціною (вхід)',
                      initialValue: _price.sourceColumn,
                      onChanged: (String v) => _markDirty(
                        () => _price = _price.copyWith(sourceColumn: v.trim()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      key: ValueKey<String>('price-out-${_price.outputColumn}'),
                      label: 'Куди писати ціну (вихід)',
                      initialValue: _price.outputColumn,
                      onChanged: (String v) => _markDirty(
                        () => _price = _price.copyWith(outputColumn: v.trim()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppSwitchRow(
                title: 'Округлювати до цілого',
                subtitle:
                    'Якщо вимкнено — у виході залишимо два знаки після крапки.',
                value: _price.roundToInt,
                onChanged: (bool v) => _markDirty(
                  () => _price = _price.copyWith(roundToInt: v),
                ),
              ),
              AppSwitchRow(
                title: 'Викидати рядки з ціною ≤ 0',
                subtitle: 'Захищає від «брухту» зі вхідного файла.',
                value: _price.dropZeroOrNegative,
                onChanged: (bool v) => _markDirty(
                  () => _price = _price.copyWith(dropZeroOrNegative: v),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: 240,
                child: AppTextField(
                  key: ValueKey<String>('price-min-${_price.minimumPrice}'),
                  label: 'Мін. ціна після націнки',
                  initialValue: _price.minimumPrice.toStringAsFixed(0),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (String v) {
                    final double parsed =
                        double.tryParse(v.replaceAll(',', '.')) ?? 0;
                    _markDirty(
                      () => _price = _price.copyWith(minimumPrice: parsed),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Дедуплікація',
          subtitle:
              'За якою колонкою прибирати дублікати у вхідному файлі (зазвичай SKU).',
          leading: const SectionLeadingIcon(icon: CupertinoIcons.square_stack_3d_up),
          child: Column(
            children: <Widget>[
              AppSwitchRow(
                title: 'Прибирати дублікати',
                value: _dedupe.enabled,
                onChanged: (bool v) => _markDirty(
                  () => _dedupe = _dedupe.copyWith(enabled: v),
                ),
              ),
              const SizedBox(height: 10),
              AppTextField(
                key: ValueKey<String>('dedupe-${_dedupe.column}'),
                label: 'Ключова колонка',
                initialValue: _dedupe.column,
                enabled: _dedupe.enabled,
                onChanged: (String v) => _markDirty(
                  () => _dedupe = _dedupe.copyWith(column: v.trim()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MappingRow extends StatelessWidget {
  const _MappingRow({
    super.key,
    required this.index,
    required this.total,
    required this.mapping,
    required this.onChanged,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index;
  final int total;
  final ColumnMapping mapping;
  final ValueChanged<ColumnMapping> onChanged;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: preset.surfaceMuted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTokens.fieldCornerRadius),
        border: Border.all(color: preset.borderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppIconButton(
                  icon: CupertinoIcons.chevron_up,
                  size: 14,
                  onPressed: index == 0 ? null : onMoveUp,
                  color: index == 0 ? preset.textMuted : null,
                ),
                AppIconButton(
                  icon: CupertinoIcons.chevron_down,
                  size: 14,
                  onPressed: index == total - 1 ? null : onMoveDown,
                  color: index == total - 1 ? preset.textMuted : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(bottom: 6, right: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: preset.iconAccentTileBackground(
                preset.heroEnd,
                CupertinoTheme.brightnessOf(context),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${index + 1}',
              style: t.labelMedium.copyWith(
                color: preset.heroEnd,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: AppTextField(
              key: ValueKey<String>('out-$index-${mapping.outputColumn}'),
              label: 'Назва колонки у виході',
              initialValue: mapping.outputColumn,
              onChanged: (String v) =>
                  onChanged(mapping.copyWith(outputColumn: v)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: AppDropdown<ColumnMappingKind>(
              label: 'Джерело',
              value: mapping.kind,
              items: const <ColumnMappingKind>[
                ColumnMappingKind.source,
                ColumnMappingKind.hardcoded,
              ],
              itemLabel: (ColumnMappingKind kind) => switch (kind) {
                ColumnMappingKind.source => 'Колонка вхідного CSV',
                ColumnMappingKind.hardcoded => 'Жорстко задане значення',
              },
              onChanged: (ColumnMappingKind next) {
                onChanged(
                  mapping.copyWith(
                    kind: next,
                    clearSource: next == ColumnMappingKind.hardcoded,
                    clearHardcoded: next == ColumnMappingKind.source,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: mapping.kind == ColumnMappingKind.source
                ? AppTextField(
                    key: ValueKey<String>(
                      'src-$index-${mapping.sourceColumn ?? ''}',
                    ),
                    label: 'Назва колонки у вхідному файлі',
                    placeholder: 'наприклад, sku',
                    initialValue: mapping.sourceColumn ?? '',
                    onChanged: (String v) =>
                        onChanged(mapping.copyWith(sourceColumn: v)),
                  )
                : AppTextField(
                    key: ValueKey<String>(
                      'val-$index-${mapping.hardcodedValue ?? ''}',
                    ),
                    label: 'Значення для всіх рядків',
                    initialValue: mapping.hardcodedValue ?? '',
                    onChanged: (String v) =>
                        onChanged(mapping.copyWith(hardcodedValue: v)),
                  ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: AppIconButton(
              icon: CupertinoIcons.trash,
              tooltip: 'Видалити',
              color: preset.dangerStrong,
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}
