import 'package:flutter/cupertino.dart';

import 'app_theme_preset.dart';

const String _kBodyFontFamily = 'Montserrat';
const String _kHeadingFontFamily = 'RobotoFlex';

/// Typography tokens for Parts Stock.
///
/// Cupertino has a thin built-in [CupertinoTextThemeData], so we keep our
/// own sized text scale that all pages can read via `context.appText`.
/// Family choices mirror the WiseWater Connect mobile app: Montserrat for
/// body / labels and RobotoFlex for headings.
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
    final TextStyle heading = TextStyle(
      fontFamily: _kHeadingFontFamily,
      color: preset.textPrimary,
      letterSpacing: -0.2,
      height: 1.24,
    );
    final TextStyle body = TextStyle(
      fontFamily: _kBodyFontFamily,
      color: preset.textSecondary,
      height: 1.42,
    );

    return AppTextStyles._(
      headlineLarge: heading.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      headlineMedium: heading.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.24,
      ),
      headlineSmall: heading.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.28,
      ),
      titleLarge: heading.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      titleMedium: heading.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        height: 1.34,
      ),
      titleSmall: heading.copyWith(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        height: 1.34,
      ),
      bodyLarge: body.copyWith(fontSize: 15),
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
      ),
      labelMedium: body.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: preset.textPrimary,
        height: 1.2,
      ),
      labelSmall: body.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: preset.textMuted,
        height: 1.2,
      ),
      button: body.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        color: preset.textPrimary,
        letterSpacing: -0.1,
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
