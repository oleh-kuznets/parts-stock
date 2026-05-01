import 'package:flutter/cupertino.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme_preset.dart';

/// Flat list of rows separated by hairline dividers.
///
/// Use this inside [SectionCard] children when you want a CleanMyMac-style
/// list (no nested bordered boxes, just rows on the card surface).
class ListGroup extends StatelessWidget {
  const ListGroup({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
    this.itemPadding = const EdgeInsets.symmetric(vertical: 12),
    this.dividerInset = 0,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final EdgeInsets itemPadding;
  final double dividerInset;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final AppThemePreset preset = context.preset;
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      rows.add(
        Padding(padding: itemPadding, child: children[i]),
      );
      if (i < children.length - 1) {
        rows.add(
          Padding(
            padding: EdgeInsets.only(left: dividerInset),
            child: Container(height: 1, color: preset.borderSoft),
          ),
        );
      }
    }
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}
