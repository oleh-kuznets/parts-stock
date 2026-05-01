import 'package:flutter/cupertino.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_theme_preset.dart';

/// Labeled Cupertino text field used everywhere instead of `TextFormField`.
///
/// The field draws its own filled rounded box (matches WiseWater chrome),
/// shows a label above the input and renders an optional helper line below.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.label,
    this.placeholder,
    this.helperText,
    this.initialValue,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.keyboardType,
    this.enabled = true,
    this.maxLines = 1,
  });

  final String? label;
  final String? placeholder;
  final String? helperText;
  final String? initialValue;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final bool enabled;
  final int maxLines;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late TextEditingController _controller;
  bool _ownsController = false;
  bool _focused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController(text: widget.initialValue ?? '');
      _ownsController = true;
    }
    _focusNode = FocusNode()..addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null &&
        oldWidget.initialValue != widget.initialValue &&
        _controller.text != (widget.initialValue ?? '')) {
      _controller.text = widget.initialValue ?? '';
    }
  }

  void _onFocus() {
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocus)
      ..dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;
    final Brightness brightness =
        CupertinoTheme.of(context).brightness ?? Brightness.light;
    final bool isDark = brightness == Brightness.dark;

    final Color fill = isDark
        ? preset.surfaceMuted.withValues(alpha: 0.36)
        : Color.lerp(preset.surfaceBase, preset.surfaceAccent, 0.68)!;
    final Color borderColor = _focused
        ? preset.heroEnd.withValues(alpha: isDark ? 0.86 : 0.78)
        : preset.borderSoft.withValues(alpha: isDark ? 0.5 : 0.62);
    final double borderWidth = _focused ? 1.4 : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.label != null) ...<Widget>[
          Text(
            widget.label!,
            style: t.labelMedium.copyWith(color: preset.textSecondary),
          ),
          const SizedBox(height: 6),
        ],
        CupertinoTextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          minLines: 1,
          keyboardType: widget.keyboardType,
          style: t.bodyMedium.copyWith(color: preset.textPrimary),
          placeholder: widget.placeholder,
          placeholderStyle: t.bodyMedium.copyWith(color: preset.textMuted),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.fieldPaddingHorizontal,
            vertical: AppTokens.fieldPaddingVertical,
          ),
          cursorColor: preset.heroEnd,
          suffix: widget.suffix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: widget.suffix,
                ),
          decoration: BoxDecoration(
            color: widget.enabled
                ? fill
                : fill.withValues(alpha: 0.5),
            borderRadius:
                BorderRadius.circular(AppTokens.fieldCornerRadius),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
        ),
        if (widget.helperText != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            widget.helperText!,
            style: t.bodySmall,
          ),
        ],
      ],
    );
  }
}
