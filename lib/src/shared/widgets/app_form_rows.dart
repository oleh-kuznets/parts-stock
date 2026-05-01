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
    final AppTextStyles t = context.appText;
    final Brightness brightness = CupertinoTheme.brightnessOf(context);
    return DefaultTextStyle.merge(
      style: t.button.copyWith(
        color: brightness == Brightness.dark
            ? preset.textPrimary
            : preset.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      child: CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        backgroundColor: preset.surfaceMuted.withValues(alpha: 0.55),
        thumbColor: preset.heroEnd,
        padding: const EdgeInsets.all(3),
        children: <T, Widget>{
          for (final MapEntry<T, Widget> entry in children.entries)
            entry.key: DefaultTextStyle.merge(
              style: TextStyle(
                color: entry.key == value
                    ? preset.heroOnPrimary
                    : preset.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              child: entry.value,
            ),
        },
        onValueChanged: (T? next) {
          if (next == null) return;
          SoundService().tap();
          onChanged(next);
        },
      ),
    );
  }
}

/// Anchored dropdown that opens a *popover* (not an action sheet) directly
/// under the trigger. Same height and chrome as [AppTextField] /
/// [AppButton] so action rows stay aligned.
class AppDropdown<T> extends StatefulWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.itemLabel,
    this.label,
    this.placeholder,
  });

  final String? label;
  final String? placeholder;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final String Function(T) itemLabel;

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>> {
  final LayerLink _link = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _entry;

  @override
  void dispose() {
    // Tear down the overlay directly — calling `_hide()` here would issue
    // a `setState` while the element is being unmounted, which trips
    // `markNeedsBuild`'s `_lifecycleState != defunct` assertion.
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void _toggle() {
    if (_entry != null) {
      _hide();
    } else {
      _show();
    }
  }

  void _show() {
    final RenderBox box =
        _triggerKey.currentContext!.findRenderObject()! as RenderBox;
    final Size size = box.size;
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;

    _entry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        return Stack(
          children: <Widget>[
            // Tap-outside catcher.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hide,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 6),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: size.width,
                  maxWidth: size.width,
                  maxHeight: 320,
                ),
                child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: preset.surfaceBase,
                      borderRadius:
                          BorderRadius.circular(AppTokens.fieldCornerRadius),
                      border: Border.all(color: preset.borderSoft),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: preset.shadowColor.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppTokens.fieldCornerRadius,
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: widget.items.length,
                      itemBuilder: (BuildContext _, int index) {
                        final T item = widget.items[index];
                        final bool selected = item == widget.value;
                        return _AppDropdownTile(
                          label: widget.itemLabel(item),
                          selected: selected,
                          preset: preset,
                          text: t,
                          onTap: () {
                            _hide();
                            if (!selected) {
                              SoundService().tap();
                              widget.onChanged(item);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);
    setState(() {});
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;
    final bool open = _entry != null;

    final String labelText = widget.itemLabel(widget.value);
    final bool empty = labelText.isEmpty;

    return CompositedTransformTarget(
      link: _link,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (widget.label != null) ...<Widget>[
            Text(
              widget.label!,
              style: t.labelMedium.copyWith(color: preset.textSecondary),
            ),
            const SizedBox(height: 6),
          ],
          CupertinoButton(
            key: _triggerKey,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            pressedOpacity: 0.86,
            onPressed: _toggle,
            child: Container(
              height: AppTokens.controlMinHeight,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.fieldPaddingHorizontal,
              ),
              decoration: BoxDecoration(
                color: preset.surfaceBase,
                borderRadius:
                    BorderRadius.circular(AppTokens.fieldCornerRadius),
                border: Border.all(
                  color: open ? preset.heroEnd : preset.borderSoft,
                  width: open ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      empty
                          ? (widget.placeholder ?? '')
                          : labelText,
                      style: t.bodyMedium.copyWith(
                        color: empty
                            ? preset.textMuted
                            : preset.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    open
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 12,
                    color: preset.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppDropdownTile extends StatefulWidget {
  const _AppDropdownTile({
    required this.label,
    required this.selected,
    required this.preset,
    required this.text,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppThemePreset preset;
  final AppTextStyles text;
  final VoidCallback onTap;

  @override
  State<_AppDropdownTile> createState() => _AppDropdownTileState();
}

class _AppDropdownTileState extends State<_AppDropdownTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = widget.preset;
    final Color bg = widget.selected
        ? preset.heroEnd.withValues(alpha: 0.12)
        : (_hover
            ? preset.surfaceMuted.withValues(alpha: 0.7)
            : const Color(0x00000000));
    final Color fg = widget.selected
        ? preset.heroEnd
        : preset.textPrimary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.label,
                    style: widget.text.bodyMedium.copyWith(
                      color: fg,
                      fontWeight:
                          widget.selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.selected) ...<Widget>[
                  const SizedBox(width: 8),
                  Icon(CupertinoIcons.checkmark_alt, size: 14, color: fg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
