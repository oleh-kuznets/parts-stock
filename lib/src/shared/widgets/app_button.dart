import 'package:flutter/cupertino.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_theme_preset.dart';
import '../../core/services/sound_service.dart';

/// All button variants share the same height, radius, padding and
/// typography — only the surface and content colors change. This keeps
/// action rows aligned to the same baseline grid.
enum AppButtonVariant { primary, secondary, danger, link }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.compact = false,
    this.loading = false,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.compact = false,
    this.loading = false,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.compact = false,
    this.loading = false,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.danger({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.compact = false,
    this.loading = false,
  }) : variant = AppButtonVariant.danger;

  /// Inline text-style action — same height as the others so it lines up in
  /// action rows, but visually feels like a hyperlink (no surface fill).
  const AppButton.link({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.compact = false,
    this.loading = false,
  }) : variant = AppButtonVariant.link;

  /// Backwards-compat alias kept so older call sites that used `.plain` keep
  /// compiling — renders identically to [AppButton.link].
  const AppButton.plain({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.compact = false,
    this.loading = false,
  }) : variant = AppButtonVariant.link;

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool compact;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;
    final bool enabled = onPressed != null && !loading;
    final double height = compact
        ? AppTokens.controlCompactHeight
        : AppTokens.controlMinHeight;
    final double horizontalPadding = compact
        ? AppTokens.buttonCompactPaddingHorizontal
        : AppTokens.buttonPaddingHorizontal;

    final _ButtonPalette palette = _palette(variant, preset, enabled: enabled);

    final Widget content = loading
        ? SizedBox(
            width: 14,
            height: 14,
            child: CupertinoActivityIndicator(color: palette.fg, radius: 7),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: compact ? 13 : 15, color: palette.fg),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: t.button.copyWith(
                  color: palette.fg,
                  fontSize: compact ? 12.5 : 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    // NOTE: do NOT set `alignment` on the container — that would force it
    // to expand to the parent's width whenever the parent is bounded
    // (e.g. inside `Align` or a stretching `Column`). The `Row` content is
    // `mainAxisSize.min` and naturally vertically centred via Row's default
    // cross-axis alignment, so the container hugs its content, which is what
    // every call site expects.
    final Widget surface = Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(AppTokens.buttonCornerRadius),
        border: palette.border,
      ),
      child: content,
    );

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      pressedOpacity: variant == AppButtonVariant.link ? 0.55 : 0.86,
      borderRadius: BorderRadius.circular(AppTokens.buttonCornerRadius),
      onPressed: enabled
          ? () {
              SoundService().tap();
              onPressed!();
            }
          : null,
      child: surface,
    );
  }

  _ButtonPalette _palette(
    AppButtonVariant variant,
    AppThemePreset preset, {
    required bool enabled,
  }) {
    switch (variant) {
      case AppButtonVariant.primary:
        final Color bg = enabled
            ? preset.heroEnd
            : Color.lerp(preset.heroEnd, preset.surfaceMuted, 0.5)!;
        return _ButtonPalette(
          bg: bg,
          fg: preset.heroOnPrimary,
          border: null,
        );
      case AppButtonVariant.secondary:
        return _ButtonPalette(
          bg: preset.surfaceBase,
          fg: enabled ? preset.textPrimary : preset.textMuted,
          border: Border.all(
            color: enabled
                ? preset.borderSoft
                : preset.borderSoft.withValues(alpha: 0.5),
            width: 1,
          ),
        );
      case AppButtonVariant.danger:
        final Color bg = enabled
            ? preset.dangerStrong
            : Color.lerp(preset.dangerStrong, preset.surfaceMuted, 0.5)!;
        return _ButtonPalette(
          bg: bg,
          fg: const Color(0xFFFFFFFF),
          border: null,
        );
      case AppButtonVariant.link:
        return _ButtonPalette(
          bg: const Color(0x00000000),
          fg: enabled ? preset.heroEnd : preset.textMuted,
          border: null,
        );
    }
  }
}

class _ButtonPalette {
  const _ButtonPalette({required this.bg, required this.fg, this.border});
  final Color bg;
  final Color fg;
  final BoxBorder? border;
}

/// Icon-only button used in lists / toolbars. Matches [AppButton]'s minimum
/// touch target and uses the same tap cue.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.size = 16,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final Color resolved = color ?? preset.textPrimary;
    final Widget button = CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(32, 32),
      pressedOpacity: 0.55,
      onPressed: onPressed == null
          ? null
          : () {
              SoundService().tap();
              onPressed!();
            },
      child: Icon(
        icon,
        size: size,
        color: onPressed == null
            ? resolved.withValues(alpha: 0.4)
            : resolved,
      ),
    );
    if (tooltip == null) return button;
    return _AppHoverTooltip(message: tooltip!, child: button);
  }
}

class _AppHoverTooltip extends StatefulWidget {
  const _AppHoverTooltip({required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  State<_AppHoverTooltip> createState() => _AppHoverTooltipState();
}

class _AppHoverTooltipState extends State<_AppHoverTooltip> {
  OverlayEntry? _entry;

  void _show() {
    if (_entry != null) return;
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final Offset origin = box.localToGlobal(Offset.zero);
    _entry = OverlayEntry(
      builder: (BuildContext context) {
        return Positioned(
          left: origin.dx,
          top: origin.dy + box.size.height + 4,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: preset.textPrimary.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  widget.message,
                  style:
                      t.labelMedium.copyWith(color: preset.scaffoldBase),
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _show(),
      onExit: (_) => _hide(),
      child: widget.child,
    );
  }
}
