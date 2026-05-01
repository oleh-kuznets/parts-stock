import 'package:flutter/cupertino.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_theme_preset.dart';
import '../../core/services/sound_service.dart';

/// Inline switch row in the iOS Settings style.
class AppSwitchRow extends StatelessWidget {
  const AppSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;
    final AppThemePreset preset = context.preset;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: t.labelLarge),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: t.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged == null
                ? null
                : (bool next) {
                    SoundService().tap();
                    onChanged!(next);
                  },
            activeTrackColor: preset.heroEnd,
          ),
        ],
      ),
    );
  }
}

/// Pill-style segmented control with our brand colors.
class AppSegmented<T extends Object> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.value,
    required this.onChanged,
    required this.children,
  });

  final T value;
  final ValueChanged<T> onChanged;
  final Map<T, Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    return CupertinoSlidingSegmentedControl<T>(
      groupValue: value,
      backgroundColor: preset.surfaceMuted.withValues(alpha: 0.6),
      thumbColor: preset.heroEnd,
      padding: const EdgeInsets.all(4),
      children: children,
      onValueChanged: (T? next) {
        if (next == null) return;
        SoundService().tap();
        onChanged(next);
      },
    );
  }
}

/// A bordered "select" button styled like an iOS context-menu trigger.
///
/// Tap → presents a [CupertinoActionSheet] of items.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.itemLabel,
  });

  final String? label;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final String Function(T) itemLabel;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Text(
            label!,
            style: t.labelMedium.copyWith(color: preset.textSecondary),
          ),
          const SizedBox(height: 6),
        ],
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _present(context),
          minimumSize: Size.zero,
          child: Container(
            height: AppTokens.controlMinHeight,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Color.lerp(
                preset.surfaceBase,
                preset.surfaceAccent,
                CupertinoTheme.brightnessOf(context) == Brightness.dark
                    ? 0.0
                    : 0.68,
              ),
              borderRadius:
                  BorderRadius.circular(AppTokens.fieldCornerRadius),
              border: Border.all(color: preset.borderSoft, width: 1.0),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    itemLabel(value),
                    style: t.bodyMedium.copyWith(color: preset.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_up_chevron_down,
                  size: 14,
                  color: preset.textMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _present(BuildContext context) async {
    final T? next = await showCupertinoModalPopup<T>(
      context: context,
      builder: (BuildContext sheetCtx) => CupertinoActionSheet(
        title: label == null ? null : Text(label!),
        actions: <Widget>[
          for (final T item in items)
            CupertinoActionSheetAction(
              isDefaultAction: item == value,
              onPressed: () => Navigator.of(sheetCtx).pop(item),
              child: Text(itemLabel(item)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () => Navigator.of(sheetCtx).pop(),
          child: const Text('Скасувати'),
        ),
      ),
    );
    if (next != null && next != value) {
      SoundService().tap();
      onChanged(next);
    }
  }
}
