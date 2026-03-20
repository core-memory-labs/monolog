import 'package:flutter/material.dart';

import '../models/topic.dart';

/// Shows a modal bottom sheet with actions for a topic:
/// rename, pin/unpin, delete.
///
/// Returns the chosen [TopicAction] or `null` if dismissed.
Future<TopicAction?> showTopicActionsSheet(
  BuildContext context, {
  required Topic topic,
}) {
  return showModalBottomSheet<TopicAction>(
    context: context,
    builder: (ctx) => _ActionsSheet(topic: topic),
  );
}

enum TopicAction { rename, togglePin, delete }

class _ActionsSheet extends StatelessWidget {
  final Topic topic;

  const _ActionsSheet({required this.topic});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                topic.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Переименовать'),
              onTap: () => Navigator.pop(context, TopicAction.rename),
            ),
            ListTile(
              leading: Icon(
                topic.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              title: Text(topic.isPinned ? 'Открепить' : 'Закрепить'),
              onTap: () => Navigator.pop(context, TopicAction.togglePin),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Удалить',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.pop(context, TopicAction.delete),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a rename dialog pre-filled with [currentTitle].
///
/// Returns the new title or `null` if cancelled.
Future<String?> showRenameDialog(
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
        title: const Text('Переименовать'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
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
  required String topicTitle,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Удалить топик?'),
        content: Text(
          'Топик «$topicTitle» и все его записи будут удалены безвозвратно.',
        ),
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
