import 'package:flutter/cupertino.dart';

import 'app_text_styles.dart';
import 'app_theme_preset.dart';

/// Theme tokens for control geometry.
abstract final class AppTokens {
  static const double fieldCornerRadius = 12;
  static const double buttonCornerRadius = 14;
  static const double cardCornerRadius = 22;
  static const double controlMinHeight = 40;
  static const double buttonMinWidth = 120;
  static const double buttonPaddingHorizontal = 22;
  static const double buttonPaddingVertical = 12;
  static const double fieldPaddingHorizontal = 14;
  static const double fieldPaddingVertical = 12;
  static const double screenGutter = 28;
  static const double sectionGap = 20;
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
