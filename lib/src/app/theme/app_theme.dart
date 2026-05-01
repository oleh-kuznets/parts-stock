import 'package:flutter/cupertino.dart';

import 'app_text_styles.dart';
import 'app_theme_preset.dart';

/// Theme tokens for control geometry.
abstract final class AppTokens {
  static const double fieldCornerRadius = 10;
  static const double buttonCornerRadius = 10;
  static const double cardCornerRadius = 18;

  /// Default control height. Buttons, fields, dropdowns and segmented
  /// controls all snap to this so action rows align cleanly to the grid.
  static const double controlMinHeight = 36;

  /// Tighter control height for inline / dense actions (page header bar).
  static const double controlCompactHeight = 30;

  static const double buttonMinWidth = 96;
  static const double buttonPaddingHorizontal = 16;
  static const double buttonCompactPaddingHorizontal = 12;

  static const double fieldPaddingHorizontal = 12;
  static const double fieldPaddingVertical = 10;

  static const double screenGutter = 28;
  static const double screenGutterCompact = 18;
  static const double sectionGap = 18;

  /// Layout breakpoints (logical pixels, excluding sidebar).
  static const double breakpointCompact = 720;
  static const double breakpointMedium = 1100;
}

/// Builds a [CupertinoThemeData] keyed by the active brand preset.
abstract final class AppCupertinoTheme {
  static CupertinoThemeData fromPreset(AppThemePreset preset, AppTextStyles t) {
    final CupertinoTextThemeData textTheme = CupertinoTextThemeData(
      primaryColor: preset.heroEnd,
      textStyle: t.bodyMedium,
      actionTextStyle: t.button.copyWith(color: preset.heroEnd),
      navTitleTextStyle: t.titleLarge.copyWith(color: preset.textPrimary),
      navLargeTitleTextStyle: t.headlineMedium.copyWith(
        color: preset.textPrimary,
      ),
      navActionTextStyle: t.button.copyWith(color: preset.heroEnd),
      pickerTextStyle: t.bodyLarge,
      dateTimePickerTextStyle: t.bodyLarge,
      tabLabelTextStyle: t.labelMedium,
    );
    return CupertinoThemeData(
      brightness: _brightnessOf(preset),
      primaryColor: preset.heroEnd,
      primaryContrastingColor: preset.heroOnPrimary,
      scaffoldBackgroundColor: preset.scaffoldBase,
      barBackgroundColor: preset.surfaceBase,
      textTheme: textTheme,
      applyThemeToAll: true,
    );
  }

  static Brightness _brightnessOf(AppThemePreset preset) {
    return preset.scaffoldBase.computeLuminance() > 0.5
        ? Brightness.light
        : Brightness.dark;
  }
}
