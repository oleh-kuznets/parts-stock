import 'package:flutter/cupertino.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_theme_preset.dart';

/// Cards used to group form sections on every page.
///
/// Pure Cupertino — soft surfaces with a 1‑pt border and the brand drop
/// shadow. Inspired by the iOS-style grouped surfaces in WiseWater Connect.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.accent,
    this.compact = false,
    EdgeInsets? padding,
  }) : padding = padding ??
            (compact
                ? const EdgeInsets.fromLTRB(16, 12, 16, 14)
                : const EdgeInsets.fromLTRB(20, 18, 20, 20));

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Color? accent;
  final bool compact;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;
    final Color border = (accent ?? preset.borderSoft).withValues(
      alpha: accent == null ? 1 : 0.4,
    );

    final TextStyle titleStyle = compact
        ? t.titleSmall.copyWith(fontWeight: FontWeight.w700)
        : t.titleMedium;
    final double headerGap = compact ? 10 : 16;
    final double leadingGap = compact ? 10 : 12;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: preset.surfaceBase,
        borderRadius: BorderRadius.circular(
          compact ? AppTokens.cardCornerRadius - 4 : AppTokens.cardCornerRadius,
        ),
        border: Border.all(color: border, width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: preset.shadowColor.withValues(alpha: compact ? 0.03 : 0.04),
            blurRadius: compact ? 16 : 24,
            offset: Offset(0, compact ? 8 : 12),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (title != null || leading != null || trailing != null)
              Padding(
                padding: EdgeInsets.only(bottom: headerGap),
                child: Row(
                  children: <Widget>[
                    if (leading != null) ...<Widget>[
                      leading!,
                      SizedBox(width: leadingGap),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (title != null) Text(title!, style: titleStyle),
                          if (subtitle != null) ...<Widget>[
                            SizedBox(height: compact ? 2 : 4),
                            Text(subtitle!, style: t.bodySmall),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...<Widget>[
                      const SizedBox(width: 12),
                      trailing!,
                    ],
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Tinted leading icon used by [SectionCard] headers.
class SectionLeadingIcon extends StatelessWidget {
  const SectionLeadingIcon({
    super.key,
    required this.icon,
    this.accent,
    this.compact = false,
  });

  final IconData icon;
  final Color? accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final Brightness brightness = CupertinoTheme.brightnessOf(context);
    final Color tint = accent ?? preset.heroEnd;
    final double size = compact ? 28 : 36;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: preset.iconAccentTileBackground(tint, brightness),
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
      ),
      child: Icon(icon, size: compact ? 14 : 18, color: tint),
    );
  }
}
