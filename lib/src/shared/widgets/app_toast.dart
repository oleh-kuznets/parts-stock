import 'package:flutter/cupertino.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme_preset.dart';
import '../../core/services/sound_service.dart';

/// Lightweight Cupertino-style toast (replaces Material's `SnackBar`).
abstract final class AppToast {
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    AppToastTone tone = AppToastTone.neutral,
    bool silent = false,
  }) {
    if (!silent) {
      switch (tone) {
        case AppToastTone.success:
          SoundService().notificationSuccessInfoAlert();
          break;
        case AppToastTone.warning:
          SoundService().notificationWarnAlert();
          break;
        case AppToastTone.danger:
          SoundService().notificationDangerAlert();
          break;
        case AppToastTone.neutral:
          // Silent — neutral copy is informational only.
          break;
      }
    }

    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    final AppThemePreset preset = context.preset;
    final AppTextStyles t = context.appText;

    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext ctx) => _ToastHost(
        message: message,
        duration: duration,
        preset: preset,
        text: t,
        tone: tone,
      ),
    );
    overlay.insert(entry);
    Future<void>.delayed(duration + const Duration(milliseconds: 600), () {
      if (entry.mounted) entry.remove();
    });
  }
}

enum AppToastTone { neutral, success, warning, danger }

class _ToastHost extends StatefulWidget {
  const _ToastHost({
    required this.message,
    required this.duration,
    required this.preset,
    required this.text,
    required this.tone,
  });

  final String message;
  final Duration duration;
  final AppThemePreset preset;
  final AppTextStyles text;
  final AppToastTone tone;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacity = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();
    Future<void>.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData? icon) = switch (widget.tone) {
      AppToastTone.neutral => (
        widget.preset.textPrimary.withValues(alpha: 0.94),
        widget.preset.scaffoldBase,
        null,
      ),
      AppToastTone.success => (
        widget.preset.successStrong.withValues(alpha: 0.95),
        const Color(0xFFFFFFFF),
        CupertinoIcons.check_mark_circled_solid,
      ),
      AppToastTone.warning => (
        widget.preset.warningStrong.withValues(alpha: 0.95),
        const Color(0xFFFFFFFF),
        CupertinoIcons.exclamationmark_triangle_fill,
      ),
      AppToastTone.danger => (
        widget.preset.dangerStrong.withValues(alpha: 0.95),
        const Color(0xFFFFFFFF),
        CupertinoIcons.exclamationmark_circle_fill,
      ),
    };

    return Positioned(
      left: 0,
      right: 0,
      bottom: 32,
      child: SafeArea(
        child: Center(
          child: SlideTransition(
            position: _offset,
            child: FadeTransition(
              opacity: _opacity,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0x66000000),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (icon != null) ...<Widget>[
                          Icon(icon, size: 18, color: fg),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Text(
                            widget.message,
                            style: widget.text.bodyMedium.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
