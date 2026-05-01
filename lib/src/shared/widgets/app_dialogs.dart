import 'package:flutter/cupertino.dart';

/// Cupertino-only confirmation modal. Returns `true` when the destructive /
/// confirm action is tapped, `false` (or `null`) when cancelled.
Future<bool?> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'OK',
  String cancelLabel = 'Скасувати',
  bool destructive = false,
}) {
  return showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(message),
      ),
      actions: <Widget>[
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        CupertinoDialogAction(
          isDefaultAction: !destructive,
          isDestructiveAction: destructive,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
