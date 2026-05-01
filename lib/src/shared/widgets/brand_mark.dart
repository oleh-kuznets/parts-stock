import 'package:flutter/cupertino.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme_preset.dart';

/// Parts Stock brand mark.
///
/// Renders the bundled raster logo (`assets/branding/app_icon_256.png`) inside
/// a rounded container that picks up the active hero gradient as a soft glow.
/// Using the bundled PNG keeps the chrome consistent with the platform app
/// icon (both are rendered from the same `logo.svg` source).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56, this.glow = true});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;
    final BorderRadius radius = BorderRadius.circular(size * 0.28);

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: glow
              ? <BoxShadow>[
                  BoxShadow(
                    color: preset.heroEnd.withValues(alpha: 0.32),
                    blurRadius: size * 0.45,
                    spreadRadius: -size * 0.18,
                    offset: Offset(0, size * 0.18),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Image.asset(
            'assets/branding/app_icon_256.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
