import 'package:flutter/cupertino.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_theme_preset.dart';
import '../../core/services/sound_service.dart';

enum AppButtonVariant { primary, secondary, plain, danger }

/// Compact branded Cupertino button used everywhere instead of Material's
/// `ElevatedButton` / `OutlinedButton` / `TextButton`.
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

  const AppButton.plain({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.compact = false,
    this.loading = false,
  }) : variant = AppButtonVariant.plain;

  const AppButton.danger({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.compact = false,
    this.loading = false,
  }) : variant = AppButtonVariant.danger;

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

    final (Color bg, Color fg, BoxBorder? border) = switch (variant) {
      AppButtonVariant.primary => (
        enabled
            ? preset.heroEnd
            : Color.lerp(preset.heroEnd, preset.surfaceMuted, 0.45)!,
        preset.heroOnPrimary,
        null,
      ),
      AppButtonVariant.secondary => (
        preset.surfaceBase,
        preset.textPrimary,
        Border.all(color: preset.borderSoft, width: 1.2),
      ),
      AppButtonVariant.plain => (
        const Color(0x00000000),
        preset.heroEnd,
        null,
      ),
      AppButtonVariant.danger => (
        enabled
            ? preset.dangerStrong
            : Color.lerp(preset.dangerStrong, preset.surfaceMuted, 0.45)!,
        const Color(0xFFFFFFFF),
        null,
      ),
    };

    final EdgeInsetsGeometry padding = compact
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
        : const EdgeInsets.symmetric(
            horizontal: AppTokens.buttonPaddingHorizontal,
            vertical: AppTokens.buttonPaddingVertical,
          );

    final Widget content = loading
        ? SizedBox(
            width: compact ? 14 : 18,
            height: compact ? 14 : 18,
            child: CupertinoActivityIndicator(color: fg, radius: 9),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: compact ? 14 : 16, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: t.button.copyWith(color: fg, fontSize: compact ? 12.5 : 14.5),
              ),
            ],
          );

    return CupertinoButton(
      padding: padding,
      onPressed: enabled
          ? () {
              SoundService().tap();
              onPressed!();
            }
          : null,
      borderRadius: BorderRadius.circular(AppTokens.buttonCornerRadius),
      color: variant == AppButtonVariant.primary ||
              variant == AppButtonVariant.danger
          ? bg
          : null,
      pressedOpacity: 0.86,
      minimumSize: Size(
        compact ? 0 : AppTokens.buttonMinWidth,
        compact ? 32 : AppTokens.controlMinHeight,
      ),
      child: variant == AppButtonVariant.secondary
          ? Container(
              padding: padding,
              decoration: BoxDecoration(
                color: bg,
                border: border,
                borderRadius:
                    BorderRadius.circular(AppTokens.buttonCornerRadius),
              ),
              constraints: BoxConstraints(
                minWidth: compact ? 0 : AppTokens.buttonMinWidth,
                minHeight: compact ? 32 : AppTokens.controlMinHeight,
              ),
              alignment: Alignment.center,
              child: content,
            )
          : content,
    );
  }
}

/// Icon-only Cupertino button used in lists / toolbars.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.size = 18,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final Widget button = CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(34, 34),
      onPressed: onPressed == null
          ? null
          : () {
              SoundService().tap();
              onPressed!();
            },
      child: Icon(icon, size: size, color: color ?? preset.textSecondary),
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
