import 'package:flutter/cupertino.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme_preset.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;
    final AppThemePreset preset = context.preset;
    final Brightness brightness = CupertinoTheme.brightnessOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: preset.iconAccentTileBackground(
                preset.heroEnd,
                brightness,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: preset.heroEnd, size: 26),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: t.titleMedium),
          if (message != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: t.bodySmall),
          ],
          if (action != null) ...<Widget>[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}
