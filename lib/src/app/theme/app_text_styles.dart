import 'package:flutter/cupertino.dart';

import 'app_theme_preset.dart';

/// Bundled SF Pro variable font — used everywhere so the typography is
/// identical on macOS (where SF is the system default) and on Windows / Linux
/// (where we ship the same file).
const String _kFontFamily = 'SF Pro';

/// Typography tokens for Parts Stock.
///
/// Cupertino's built-in [CupertinoTextThemeData] is intentionally thin, so we
/// keep our own scale that pages reach via `context.appText`. Both display and
/// body use the same family (SF Pro) — only weight, size and tracking change.
@immutable
class AppTextStyles {
  const AppTextStyles._({
    required this.headlineLarge,
    required this.headlineMedium,
    required this.headlineSmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
    required this.button,
  });

  factory AppTextStyles.fromPreset(AppThemePreset preset) {
    final TextStyle base = TextStyle(
      fontFamily: _kFontFamily,
      color: preset.textPrimary,
      // SF benefits from a slightly negative tracking at display sizes.
      letterSpacing: -0.2,
      height: 1.24,
    );
    final TextStyle body = base.copyWith(
      color: preset.textSecondary,
      height: 1.45,
      letterSpacing: -0.05,
    );

    return AppTextStyles._(
      headlineLarge: base.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.18,
        letterSpacing: -0.4,
      ),
      headlineMedium: base.copyWith(
        fontSize: 23,
        fontWeight: FontWeight.w700,
        height: 1.22,
        letterSpacing: -0.35,
      ),
      headlineSmall: base.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.26,
        letterSpacing: -0.3,
      ),
      titleLarge: base.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.2,
      ),
      titleMedium: base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.34,
        letterSpacing: -0.15,
      ),
      titleSmall: base.copyWith(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        height: 1.34,
        letterSpacing: -0.1,
      ),
      bodyLarge: body.copyWith(fontSize: 15, color: preset.textPrimary),
      bodyMedium: body.copyWith(fontSize: 14),
      bodySmall: body.copyWith(
        fontSize: 12,
        color: preset.textMuted,
        height: 1.36,
      ),
      labelLarge: body.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: preset.textPrimary,
        height: 1.2,
        letterSpacing: -0.05,
      ),
      labelMedium: body.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: preset.textPrimary,
        height: 1.2,
        letterSpacing: 0,
      ),
      labelSmall: body.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: preset.textMuted,
        height: 1.2,
        letterSpacing: 0.1,
      ),
      button: base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: preset.textPrimary,
        letterSpacing: -0.05,
        height: 1.2,
      ),
    );
  }

  final TextStyle headlineLarge;
  final TextStyle headlineMedium;
  final TextStyle headlineSmall;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle titleSmall;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle labelLarge;
  final TextStyle labelMedium;
  final TextStyle labelSmall;
  final TextStyle button;
}

/// InheritedWidget that propagates the active [AppTextStyles] / [AppThemePreset]
/// pair throughout the widget tree. Pages reach into it via `context.appText`
/// and `context.preset`.
class AppStyleScope extends InheritedWidget {
  const AppStyleScope({
    super.key,
    required this.preset,
    required this.text,
    required super.child,
  });

  final AppThemePreset preset;
  final AppTextStyles text;

  static AppStyleScope of(BuildContext context) {
    final AppStyleScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppStyleScope>();
    assert(scope != null, 'AppStyleScope is missing above this widget.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppStyleScope oldWidget) {
    return oldWidget.preset != preset || oldWidget.text != text;
  }
}

extension AppStyleContext on BuildContext {
  AppThemePreset get preset => AppStyleScope.of(this).preset;
  AppTextStyles get appText => AppStyleScope.of(this).text;
}
