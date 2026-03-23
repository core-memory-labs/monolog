import 'package:flutter/material.dart';

/// Shows an edit dialog pre-filled with [currentTitle].
///
/// Returns the new title or `null` if cancelled.
Future<String?> showEditDialog(
  BuildContext context, {
  required String currentTitle,
}) {
  final controller = TextEditingController(text: currentTitle);
  // Select all text for easy replacement.
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: currentTitle.length,
  );

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Редактирование'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 100,
          decoration: const InputDecoration(
            hintText: 'Название топика',
          ),
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) Navigator.pop(ctx, trimmed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) Navigator.pop(ctx, trimmed);
            },
            child: const Text('Сохранить'),
          ),
        ],
      );
    },
  );
}

/// Shows a delete confirmation dialog.
///
/// Returns `true` if confirmed, `false` / `null` otherwise.
Future<bool?> showDeleteConfirmation(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Удалить',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      );
    },
  );
}

/// Shows a confirmation dialog when the user tries to discard unsaved changes
/// (e.g. cancelling an edit with modified text or attachment).
///
/// Returns `true` if the user confirms discarding, `false` / `null` otherwise.
Future<bool?> showDiscardConfirmation(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Отменить изменения?'),
        content: const Text('Несохранённые изменения будут потеряны.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Продолжить редактирование'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отменить'),
          ),
        ],
      );
    },
  );
}
