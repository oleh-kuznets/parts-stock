import 'package:flutter/cupertino.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_theme_preset.dart';

/// Standard Cupertino page chrome — scrollable content with consistent
/// gutters. The page-level title/subtitle live inside each page's hero
/// (see `FeatureHero` / `HeroPanel`), so this scaffold no longer renders
/// a separate header strip on top.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.children,
    this.padded = true,
  });

  final List<Widget> children;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final AppThemePreset preset = context.preset;

    return ColoredBox(
      color: preset.scaffoldBase,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double gutter =
              constraints.maxWidth < AppTokens.breakpointCompact
              ? AppTokens.screenGutterCompact
              : AppTokens.screenGutter;

          return CustomScrollView(
            slivers: <Widget>[
              SliverPadding(
                padding: padded
                    ? EdgeInsets.fromLTRB(gutter, 24, gutter, 32)
                    : EdgeInsets.zero,
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      if (index.isOdd) {
                        return const SizedBox(height: AppTokens.sectionGap);
                      }
                      return children[index ~/ 2];
                    },
                    childCount:
                        children.isEmpty ? 0 : children.length * 2 - 1,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
