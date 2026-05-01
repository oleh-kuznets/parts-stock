import 'package:flutter/cupertino.dart';

/// Brand palette for Parts Stock.
///
/// Inspired by the WiseWater Connect mobile app: dense slate scaffolds,
/// soft surfaces with subtle borders, and a deep blue accent that scales
/// from a near-black hero start into a vibrant action blue.
@immutable
class AppThemePreset {
  const AppThemePreset({
    required this.scaffoldBase,
    required this.surfaceBase,
    required this.surfaceMuted,
    required this.surfaceAccent,
    required this.borderSoft,
    required this.borderAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.shadowColor,
    required this.heroStart,
    required this.heroMiddle,
    required this.heroEnd,
    required this.heroOnPrimary,
    required this.heroOnMuted,
    required this.infoSoft,
    required this.infoStrong,
    required this.successSoft,
    required this.successStrong,
    required this.warningSoft,
    required this.warningStrong,
    required this.dangerSoft,
    required this.dangerStrong,
  });

  const AppThemePreset.light()
    : this(
        scaffoldBase: const Color(0xFFF0F2F5),
        surfaceBase: const Color(0xFFF7F8FA),
        surfaceMuted: const Color(0xFFECEEF2),
        surfaceAccent: const Color(0xFFE8EEF6),
        borderSoft: const Color(0xFFD5DEE8),
        borderAccent: const Color(0xFFA5C9FF),
        textPrimary: const Color(0xFF111827),
        textSecondary: const Color(0xFF6B7280),
        textMuted: const Color(0xFF9CA3AF),
        shadowColor: const Color(0xFF1E3A8A),
        heroStart: const Color(0xFF001431),
        heroMiddle: const Color(0xFF003585),
        heroEnd: const Color(0xFF0267FF),
        heroOnPrimary: const Color(0xFFFFFFFF),
        heroOnMuted: const Color(0xFFCEE1FF),
        infoSoft: const Color(0xFFEEF5FF),
        infoStrong: const Color(0xFF0056D6),
        successSoft: const Color(0xFFECFDF3),
        successStrong: const Color(0xFF15803D),
        warningSoft: const Color(0xFFFFF7E6),
        warningStrong: const Color(0xFFB45309),
        dangerSoft: const Color(0xFFFEF2F2),
        dangerStrong: const Color(0xFFB91C1C),
      );

  const AppThemePreset.dark()
    : this(
        scaffoldBase: const Color(0xFF050914),
        surfaceBase: const Color(0xFF111827),
        surfaceMuted: const Color(0xFF1F2937),
        surfaceAccent: const Color(0xFF00255C),
        borderSoft: const Color(0xFF374151),
        borderAccent: const Color(0xFF0056D6),
        textPrimary: const Color(0xFFF9FAFB),
        textSecondary: const Color(0xFFD1D5DB),
        textMuted: const Color(0xFF9CA3AF),
        shadowColor: const Color(0xFF030712),
        heroStart: const Color(0xFF050914),
        heroMiddle: const Color(0xFF001431),
        heroEnd: const Color(0xFF0045AD),
        heroOnPrimary: const Color(0xFFF9FAFB),
        heroOnMuted: const Color(0xFFCEE1FF),
        infoSoft: const Color(0xFF001F4A),
        infoStrong: const Color(0xFFA5C9FF),
        successSoft: const Color(0xFF052E1B),
        successStrong: const Color(0xFF86EFAC),
        warningSoft: const Color(0xFF3B1F05),
        warningStrong: const Color(0xFFFCD34D),
        dangerSoft: const Color(0xFF3F0A0A),
        dangerStrong: const Color(0xFFFCA5A5),
      );

  final Color scaffoldBase;
  final Color surfaceBase;
  final Color surfaceMuted;
  final Color surfaceAccent;
  final Color borderSoft;
  final Color borderAccent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color shadowColor;
  final Color heroStart;
  final Color heroMiddle;
  final Color heroEnd;
  final Color heroOnPrimary;
  final Color heroOnMuted;
  final Color infoSoft;
  final Color infoStrong;
  final Color successSoft;
  final Color successStrong;
  final Color warningSoft;
  final Color warningStrong;
  final Color dangerSoft;
  final Color dangerStrong;

  /// Squircle background for muted leading icons in tiles / list items.
  Color iconMutedTileBackground(Brightness brightness) {
    if (brightness == Brightness.light) {
      return Color.lerp(surfaceMuted, textPrimary, 0.1)!;
    }
    return textPrimary.withValues(alpha: 0.14);
  }

  /// Squircle background for accent-tinted leading icons.
  Color iconAccentTileBackground(Color accent, Brightness brightness) {
    if (brightness == Brightness.light) {
      return Color.lerp(surfaceMuted, accent, 0.15)!;
    }
    return accent.withValues(alpha: 0.18);
  }
}
