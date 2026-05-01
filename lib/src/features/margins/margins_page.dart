import 'package:flutter/cupertino.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme_preset.dart';
import '../../core/models/converter_config.dart';
import '../../core/services/sound_service.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/hero_panel.dart';
import '../../shared/widgets/list_group.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/section_card.dart';

class MarginsPage extends StatefulWidget {
  const MarginsPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<MarginsPage> createState() => _MarginsPageState();
}

class _MarginsPageState extends State<MarginsPage> {
  late List<MarginRule> _draft;
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
    setState(() {
      _draft = List<MarginRule>.of(widget.appState.config.margins);
    });
  }

  void _markDirty(VoidCallback mutator) {
    setState(() {
      mutator();
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final List<MarginRule> sorted = List<MarginRule>.of(_draft)
      ..sort((MarginRule a, MarginRule b) => a.minPrice.compareTo(b.minPrice));
    await widget.appState.replaceMargins(sorted);
    if (!mounted) return;
    setState(() {
      _draft = sorted;
      _dirty = false;
    });
    SoundService().saved();
    AppToast.show(
      context,
      'Збережено',
      tone: AppToastTone.success,
      silent: true,
    );
  }

  void _addRule() {
    final double maxKnown = _draft
        .map((MarginRule r) => r.maxPrice ?? r.minPrice)
        .fold<double>(0, (double a, double b) => a > b ? a : b);
    _markDirty(() {
      _draft.add(
        MarginRule(
          minPrice: maxKnown,
          maxPrice: maxKnown == 0 ? 100 : maxKnown + 100,
          multiplier: 1.10,
        ),
      );
    });
  }

  void _removeRule(int index) {
    _markDirty(() => _draft.removeAt(index));
  }

  void _updateRule(int index, MarginRule next) {
    _markDirty(() => _draft[index] = next);
  }

  double _maxMarkupPercent() {
    double max = 0;
    for (final MarginRule r in _draft) {
      if (r.markupPercent > max) max = r.markupPercent;
    }
    return max;
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      children: <Widget>[
        FeatureHero(
          icon: CupertinoIcons.percent,
          eyebrow: _dirty ? 'Не зберіг' : 'Як накручуємо',
          title: _dirty
              ? 'Збережи зміни'
              : 'Накручуємо ціну за діапазонами',
          subtitle:
              'Спрацьовує перше правило, у діапазон якого потрапила ціна. Залиш «до» порожнім — це буде «на всі ціни вище».',
          stats: <Widget>[
            HeroStatChip(
              label: 'Правил',
              value: '${_draft.length}',
              icon: CupertinoIcons.percent,
            ),
            if (_draft.isNotEmpty)
              HeroStatChip(
                label: 'Макс націнка',
                value: '${_maxMarkupPercent().toStringAsFixed(0)}%',
                icon: CupertinoIcons.arrow_up_right,
                tone: HeroChipTone.warning,
              ),
            if (_draft.any((MarginRule r) => r.maxPrice == null))
              const HeroStatChip(
                label: 'Без верху',
                value: 'є',
                icon: CupertinoIcons.infinite,
                tone: HeroChipTone.positive,
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
          title: 'Діапазони цін',
          subtitle:
              'Якщо ціна ≥ «від» і < «до» — помнож на націнку. «До» порожнє = «без верху».',
          leading: const SectionLeadingIcon(icon: CupertinoIcons.percent),
          trailing: AppButton.secondary(
            icon: CupertinoIcons.add,
            label: 'Додати',
            onPressed: _addRule,
            compact: true,
          ),
          child: _draft.isEmpty
              ? EmptyState(
                  icon: CupertinoIcons.percent,
                  title: 'Поки немає правил',
                  message:
                      'Без правил ціна піде у вихід без змін. Натисни «Додати», щоб створити перше.',
                  action: AppButton.primary(
                    icon: CupertinoIcons.add,
                    label: 'Додати',
                    onPressed: _addRule,
                  ),
                )
              : ListGroup(
                  itemPadding: const EdgeInsets.symmetric(vertical: 14),
                  children: <Widget>[
                    for (int i = 0; i < _draft.length; i++)
                      _MarginRow(
                        index: i,
                        rule: _draft[i],
                        onChanged: (MarginRule next) => _updateRule(i, next),
                        onRemove: () => _removeRule(i),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _MarginRow extends StatelessWidget {
  const _MarginRow({
    required this.index,
    required this.rule,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final MarginRule rule;
  final ValueChanged<MarginRule> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;
    final double markupPercent = rule.markupPercent;

    final Widget badge = Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(bottom: 6, right: 12),
      decoration: BoxDecoration(
        color: preset.iconAccentTileBackground(
          preset.heroEnd,
          CupertinoTheme.brightnessOf(context),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        '${index + 1}',
        style: t.titleSmall.copyWith(
          color: preset.heroEnd,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );

    final Widget minField = AppTextField(
      key: ValueKey<String>('min-$index-${rule.minPrice}'),
      label: 'Від (ціна ≥)',
      initialValue: rule.minPrice.toStringAsFixed(0),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (String v) {
        final double parsed = double.tryParse(v.replaceAll(',', '.')) ?? 0;
        onChanged(rule.copyWith(minPrice: parsed));
      },
    );

    final Widget maxField = AppTextField(
      key: ValueKey<String>('max-$index-${rule.maxPrice ?? -1}'),
      label: 'До (ціна <)',
      placeholder: '∞',
      initialValue: rule.maxPrice?.toStringAsFixed(0) ?? '',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (String v) {
        if (v.trim().isEmpty) {
          onChanged(rule.copyWith(clearMax: true));
          return;
        }
        final double? parsed = double.tryParse(v.replaceAll(',', '.'));
        if (parsed == null) return;
        onChanged(rule.copyWith(maxPrice: parsed));
      },
    );

    final Widget percentField = AppTextField(
      key: ValueKey<String>('mul-$index-${rule.multiplier}'),
      label: 'Націнка',
      initialValue: markupPercent.toStringAsFixed(
        markupPercent == markupPercent.roundToDouble() ? 0 : 2,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      suffix: Text(
        '%',
        style: t.bodyMedium.copyWith(color: preset.textMuted),
      ),
      onChanged: (String v) {
        final double percent = double.tryParse(v.replaceAll(',', '.')) ?? 0;
        onChanged(rule.copyWith(multiplier: 1 + (percent / 100)));
      },
    );

    final Widget labelField = AppTextField(
      key: ValueKey<String>('label-$index'),
      label: 'Назва (можна пропустити)',
      initialValue: rule.label ?? '',
      onChanged: (String v) => onChanged(rule.copyWith(label: v)),
    );

    final Widget removeButton = Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 6),
      child: AppIconButton(
        icon: CupertinoIcons.trash,
        tooltip: 'Видалити',
        color: preset.dangerStrong,
        onPressed: onRemove,
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        badge,
        Expanded(flex: 3, child: minField),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: maxField),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: percentField),
        const SizedBox(width: 10),
        Expanded(flex: 4, child: labelField),
        removeButton,
      ],
    );
  }
}
