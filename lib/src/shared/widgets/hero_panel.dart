import 'package:flutter/cupertino.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_theme_preset.dart';
import '../../core/services/sound_service.dart';

/// Small frosted icon stamp shown beside the eyebrow in [FeatureHero].
///
/// Sized for a "page emblem" — no longer a giant tile. Stays subtle so the
/// real focal point is the title + KPI chips.
class HeroFeatureIcon extends StatelessWidget {
  const HeroFeatureIcon({super.key, required this.icon, this.size = 36});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: const Color(0x29FFFFFF)),
      ),
      child: Icon(icon, size: size * 0.5, color: CupertinoColors.white),
    );
  }
}

/// Compact KPI chip rendered on the gradient hero — frosted glass style.
class HeroStatChip extends StatelessWidget {
  const HeroStatChip({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.tone = HeroChipTone.neutral,
  });

  final String label;
  final String value;
  final IconData? icon;
  final HeroChipTone tone;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;
    final Color background;
    final Color border;
    switch (tone) {
      case HeroChipTone.neutral:
        background = const Color(0x1FFFFFFF);
        border = const Color(0x29FFFFFF);
        break;
      case HeroChipTone.warning:
        background = const Color(0x40FACC15);
        border = const Color(0x66FACC15);
        break;
      case HeroChipTone.positive:
        background = const Color(0x4034D399);
        border = const Color(0x6634D399);
        break;
    }
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              size: 12,
              color: CupertinoColors.white.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: t.labelSmall.copyWith(
              color: CupertinoColors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: t.labelSmall.copyWith(
              color: CupertinoColors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

enum HeroChipTone { neutral, warning, positive }

/// Static feature-page hero: icon tile + headline + KPI chips + CTA.
///
/// Use for "configuration" pages (Mappings, Margins, Settings) where the
/// page doesn't have a live progress to show but should still feel rich
/// and CleanMyMac-grade.
class FeatureHero extends StatelessWidget {
  const FeatureHero({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.stats = const <Widget>[],
    this.primary,
    this.secondary,
    this.tone = HeroTone.brand,
    this.compact = false,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> stats;
  final Widget? primary;
  final Widget? secondary;
  final HeroTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;
    final double iconSize = compact ? 26 : 30;
    final double titleSize = compact ? 22 : 28;
    final double subtitleSize = compact ? 13 : 14;
    return HeroPanel(
      tone: tone,
      padding: compact
          ? const EdgeInsets.fromLTRB(22, 18, 22, 20)
          : const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              HeroFeatureIcon(icon: icon, size: iconSize),
              SizedBox(width: compact ? 10 : 12),
              Text(
                eyebrow.toUpperCase(),
                style: t.labelSmall.copyWith(
                  color: CupertinoColors.white.withValues(alpha: 0.78),
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            title,
            style: t.headlineLarge.copyWith(
              color: CupertinoColors.white,
              fontSize: titleSize,
              letterSpacing: -0.5,
              height: 1.12,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            subtitle,
            style: t.bodyMedium.copyWith(
              color: CupertinoColors.white.withValues(alpha: 0.78),
              fontSize: subtitleSize,
              height: 1.4,
            ),
          ),
          if (stats.isNotEmpty) ...<Widget>[
            SizedBox(height: compact ? 14 : 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stats,
            ),
          ],
          if (primary != null || secondary != null) ...<Widget>[
            SizedBox(height: compact ? 16 : 22),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                ?primary,
                ?secondary,
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Inline hero ghost button — text-only CTA on the gradient surface that
/// pairs with [HeroActionButton] as a secondary action.
class HeroGhostButton extends StatelessWidget {
  const HeroGhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;
    final bool enabled = onPressed != null;
    final double height = compact ? 36 : 44;
    final double horizontalPadding = compact ? 16 : 18;
    final double iconSize = compact ? 14 : 15;
    final double fontSize = compact ? 12.5 : 14;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      pressedOpacity: 0.65,
      onPressed: enabled
          ? () {
              SoundService().tap();
              onPressed!();
            }
          : null,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0x1FFFFFFF)
              : const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: enabled
                ? const Color(0x33FFFFFF)
                : const Color(0x1FFFFFFF),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: iconSize,
                color: CupertinoColors.white.withValues(
                  alpha: enabled ? 0.95 : 0.5,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: t.button.copyWith(
                color: CupertinoColors.white.withValues(
                  alpha: enabled ? 0.95 : 0.5,
                ),
                fontWeight: FontWeight.w600,
                fontSize: fontSize,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big gradient hero panel — used at the top of "spotlight" pages
/// (Convert, future Dashboard) to draw the eye to the primary action.
///
/// Inspired by CleanMyMac's "scan" hero card: deep navy gradient with a
/// soft outer glow and a frosted highlight along the top edge.
class HeroPanel extends StatelessWidget {
  const HeroPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(28),
    this.glow = true,
    this.tone = HeroTone.brand,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool glow;
  final HeroTone tone;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;

    final List<Color> gradient;
    final Color glowColor;
    switch (tone) {
      case HeroTone.brand:
        gradient = <Color>[
          preset.heroStart,
          preset.heroMiddle,
          preset.heroEnd,
        ];
        glowColor = preset.heroEnd;
        break;
      case HeroTone.success:
        gradient = <Color>[
          preset.heroStart,
          Color.lerp(preset.heroMiddle, preset.successStrong, 0.45)!,
          preset.successStrong,
        ];
        glowColor = preset.successStrong;
        break;
      case HeroTone.danger:
        gradient = <Color>[
          preset.heroStart,
          Color.lerp(preset.heroMiddle, preset.dangerStrong, 0.5)!,
          preset.dangerStrong,
        ];
        glowColor = preset.dangerStrong;
        break;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.cardCornerRadius + 4),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
          stops: const <double>[0, 0.55, 1],
        ),
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.35),
                  blurRadius: 38,
                  spreadRadius: -10,
                  offset: const Offset(0, 18),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: <Widget>[
          // Top highlight — gives the panel that frosted glass feel.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTokens.cardCornerRadius + 4),
              ),
              child: Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0x33FFFFFF),
                      Color(0x00FFFFFF),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

enum HeroTone { brand, success, danger }

/// Oversized pill action button intended to live inside [HeroPanel].
///
/// Same tap cue as [AppButton] but with a chunkier height, gradient surface
/// and a soft outer glow so it always feels like the page's primary call to
/// action.
class HeroActionButton extends StatelessWidget {
  const HeroActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;
    final bool enabled = onPressed != null && !loading;

    final List<Color> gradient = enabled
        ? <Color>[
            const Color(0xFFFFFFFF),
            const Color(0xFFE9F1FF),
          ]
        : <Color>[
            const Color(0xCCFFFFFF),
            const Color(0x99FFFFFF),
          ];

    final double height = compact ? 36 : 52;
    final double horizontalPadding = compact ? 18 : 32;
    final double minWidth = compact ? 0 : 220;
    final double iconSize = compact ? 14 : 18;
    final double fontSize = compact ? 12.5 : 15.5;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      pressedOpacity: 0.92,
      onPressed: enabled
          ? () {
              SoundService().tap();
              onPressed!();
            }
          : null,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        constraints: BoxConstraints(minWidth: minWidth),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled
              ? <BoxShadow>[
                  const BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                    spreadRadius: -8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (loading)
              SizedBox(
                width: iconSize,
                height: iconSize,
                child: CupertinoActivityIndicator(
                  color: preset.heroEnd,
                  radius: iconSize / 2,
                ),
              )
            else if (icon != null)
              Icon(icon, size: iconSize, color: preset.heroEnd),
            if ((loading || icon != null)) const SizedBox(width: 10),
            Text(
              label,
              style: t.button.copyWith(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: preset.heroEnd,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
