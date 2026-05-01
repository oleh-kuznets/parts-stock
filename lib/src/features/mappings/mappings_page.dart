import 'package:flutter/cupertino.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme_preset.dart';
import '../../core/models/converter_config.dart';
import '../../core/services/sound_service.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_form_rows.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/hero_panel.dart';
import '../../shared/widgets/list_group.dart';
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
      'Збережено',
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
      children: <Widget>[
        FeatureHero(
          icon: CupertinoIcons.square_grid_2x2,
          tone: _dirty ? HeroTone.brand : HeroTone.brand,
          eyebrow: _dirty ? 'Не зберіг' : 'Колонки',
          title: _dirty
              ? 'Збережи зміни'
              : 'Як виглядатиме вихід',
          subtitle:
              'Кожна колонка йде або з вхідного файлу, або фіксованим значенням. Повтори можна прибрати за ключем.',
          stats: <Widget>[
            HeroStatChip(
              label: 'Колонок',
              value: '${_draft.length}',
              icon: CupertinoIcons.square_grid_2x2,
            ),
            HeroStatChip(
              label: 'Ціна',
              value:
                  '${_price.sourceColumn.isEmpty ? '?' : _price.sourceColumn} → '
                  '${_price.outputColumn.isEmpty ? '?' : _price.outputColumn}',
              icon: CupertinoIcons.tag,
            ),
            HeroStatChip(
              label: 'Без повторів',
              value: _dedupe.enabled
                  ? (_dedupe.column.isEmpty ? 'так' : _dedupe.column)
                  : 'ні',
              icon: CupertinoIcons.square_stack_3d_up,
              tone: _dedupe.enabled
                  ? HeroChipTone.positive
                  : HeroChipTone.neutral,
            ),
          ],
          primary: _dirty
              ? HeroActionButton(
                  label: 'Зберегти зміни',
                  icon: CupertinoIcons.checkmark_alt,
                  onPressed: _save,
                )
              : null,
          secondary: _dirty
              ? HeroGhostButton(
                  label: 'Скасувати',
                  icon: CupertinoIcons.arrow_uturn_left,
                  onPressed: () {
                    setState(() => _dirty = false);
                    _resync();
                  },
                )
              : null,
        ),
        SectionCard(
          title: 'Колонки на виході',
          subtitle:
              'Зверху вниз — у такому ж порядку буде в CSV. Стрілки міняють місцями.',
          leading:
              const SectionLeadingIcon(icon: CupertinoIcons.square_grid_2x2),
          trailing: AppButton.secondary(
            icon: CupertinoIcons.add,
            label: 'Додати',
            onPressed: _addRow,
            compact: true,
          ),
          child: _draft.isEmpty
              ? EmptyState(
                  icon: CupertinoIcons.square_grid_2x2,
                  title: 'Тут поки порожньо',
                  message: 'Натисни «Додати», щоб створити першу колонку.',
                  action: AppButton.primary(
                    icon: CupertinoIcons.add,
                    label: 'Додати',
                    onPressed: _addRow,
                  ),
                )
              : ListGroup(
                  itemPadding: const EdgeInsets.symmetric(vertical: 14),
                  children: <Widget>[
                    for (int i = 0; i < _draft.length; i++)
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
                ),
        ),
        SectionCard(
          title: 'Ціна',
          subtitle:
              'Звідки брати ціну і куди її писати після націнки.',
          leading: const SectionLeadingIcon(icon: CupertinoIcons.tag),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      key: ValueKey<String>('price-src-${_price.sourceColumn}'),
                      label: 'Звідки беремо ціну',
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
                      label: 'Куди записати',
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
                title: 'Округлити до цілого',
                subtitle:
                    'Інакше залишимо два знаки після крапки.',
                value: _price.roundToInt,
                onChanged: (bool v) => _markDirty(
                  () => _price = _price.copyWith(roundToInt: v),
                ),
              ),
              AppSwitchRow(
                title: 'Викидати рядки без ціни',
                subtitle: 'Якщо ціна 0 або менше — товар без ціни, пропустимо.',
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
                  label: 'Мінімальна ціна після націнки',
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
          title: 'Прибирати повтори',
          subtitle:
              'За якою колонкою шукати дублікати (зазвичай SKU).',
          leading: const SectionLeadingIcon(icon: CupertinoIcons.square_stack_3d_up),
          child: Column(
            children: <Widget>[
              AppSwitchRow(
                title: 'Прибирати повтори',
                value: _dedupe.enabled,
                onChanged: (bool v) => _markDirty(
                  () => _dedupe = _dedupe.copyWith(enabled: v),
                ),
              ),
              const SizedBox(height: 10),
              AppTextField(
                key: ValueKey<String>('dedupe-${_dedupe.column}'),
                label: 'Колонка-ключ',
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

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stack = constraints.maxWidth < 720;

        final Widget reorder = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppIconButton(
              icon: CupertinoIcons.chevron_up,
              size: 13,
              onPressed: index == 0 ? null : onMoveUp,
            ),
            AppIconButton(
              icon: CupertinoIcons.chevron_down,
              size: 13,
              onPressed: index == total - 1 ? null : onMoveDown,
            ),
          ],
        );

        final Widget indexBadge = Container(
          width: 28,
          height: 28,
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
        );

        final Widget outputField = AppTextField(
          key: ValueKey<String>('out-$index-${mapping.outputColumn}'),
          label: 'Назва у CSV',
          initialValue: mapping.outputColumn,
          onChanged: (String v) => onChanged(mapping.copyWith(outputColumn: v)),
        );

        final Widget kindDropdown = AppDropdown<ColumnMappingKind>(
          label: 'Звідки беремо',
          value: mapping.kind,
          items: const <ColumnMappingKind>[
            ColumnMappingKind.source,
            ColumnMappingKind.hardcoded,
          ],
          itemLabel: (ColumnMappingKind kind) => switch (kind) {
            ColumnMappingKind.source => 'З колонки вхідного',
            ColumnMappingKind.hardcoded => 'Своє значення',
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
        );

        final Widget detailField = mapping.kind == ColumnMappingKind.source
            ? AppTextField(
                key: ValueKey<String>('src-$index-${mapping.sourceColumn ?? ''}'),
                label: 'Назва у вхідному CSV',
                placeholder: 'наприклад, sku',
                initialValue: mapping.sourceColumn ?? '',
                onChanged: (String v) =>
                    onChanged(mapping.copyWith(sourceColumn: v)),
              )
            : AppTextField(
                key: ValueKey<String>(
                  'val-$index-${mapping.hardcodedValue ?? ''}',
                ),
                label: 'Що писати в кожен рядок',
                initialValue: mapping.hardcodedValue ?? '',
                onChanged: (String v) =>
                    onChanged(mapping.copyWith(hardcodedValue: v)),
              );

        final Widget removeButton = AppIconButton(
          icon: CupertinoIcons.trash,
          tooltip: 'Видалити',
          color: preset.dangerStrong,
          onPressed: onRemove,
        );

        if (stack) {
          // Narrow layout: each input takes the full width and the controls
          // wrap into their own row.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  indexBadge,
                  const SizedBox(width: 10),
                  Expanded(child: outputField),
                ],
              ),
              const SizedBox(height: 12),
              kindDropdown,
              const SizedBox(height: 12),
              detailField,
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[reorder, removeButton],
              ),
            ],
          );
        }

        // Wide layout: 3 equal-width inputs on a single grid line — no
        // nested container, this row sits directly on the SectionCard
        // surface and is separated from neighbours by a hairline.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: reorder,
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: indexBadge,
            ),
            const SizedBox(width: 10),
            Expanded(child: outputField),
            const SizedBox(width: 12),
            Expanded(child: kindDropdown),
            const SizedBox(width: 12),
            Expanded(child: detailField),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: removeButton,
            ),
          ],
        );
      },
    );
  }
}
