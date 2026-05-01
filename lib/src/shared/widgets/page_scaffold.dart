import 'package:flutter/cupertino.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_theme_preset.dart';

/// Standard Cupertino page chrome — header strip + scrollable content.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.actions,
    this.padded = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget>? actions;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles t = context.appText;
    final AppThemePreset preset = context.preset;

    return ColoredBox(
      color: preset.scaffoldBase,
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.screenGutter,
                28,
                AppTokens.screenGutter,
                12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: t.headlineMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(subtitle!, style: t.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                  if (actions != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (int i = 0; i < actions!.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: 8),
                          actions![i],
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: padded
                ? const EdgeInsets.fromLTRB(
                    AppTokens.screenGutter,
                    8,
                    AppTokens.screenGutter,
                    32,
                  )
                : EdgeInsets.zero,
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  if (index.isOdd) {
                    return const SizedBox(height: AppTokens.sectionGap);
                  }
                  return children[index ~/ 2];
                },
                childCount: children.isEmpty ? 0 : children.length * 2 - 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
