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
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 20),
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Color? accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;
    final Color border = (accent ?? preset.borderSoft).withValues(
      alpha: accent == null ? 1 : 0.4,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: preset.surfaceBase,
        borderRadius: BorderRadius.circular(AppTokens.cardCornerRadius),
        border: Border.all(color: border, width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: preset.shadowColor.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
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
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: <Widget>[
                    if (leading != null) ...<Widget>[
                      leading!,
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (title != null)
                            Text(title!, style: t.titleMedium),
                          if (subtitle != null) ...<Widget>[
                            const SizedBox(height: 4),
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
  const SectionLeadingIcon({super.key, required this.icon, this.accent});

  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final Brightness brightness = CupertinoTheme.brightnessOf(context);
    final Color tint = accent ?? preset.heroEnd;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: preset.iconAccentTileBackground(tint, brightness),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: tint),
    );
  }
}
