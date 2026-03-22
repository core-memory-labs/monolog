import 'package:flutter/material.dart';

/// Messenger-style input field at the bottom of the entry feed.
///
/// In normal mode shows a text field with an "arrow up" send button.
/// In edit mode shows a "Редактирование" banner with cancel (×) and
/// the send button changes to a checkmark.
class EntryInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final bool isEditing;
  final VoidCallback? onCancelEdit;

  const EntryInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    this.isEditing = false,
    this.onCancelEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Edit-mode indicator
          if (isEditing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color:
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(
                    Icons.edit,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Редактирование',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onCancelEdit,
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

          // Text field + send button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 5,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Запись…',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: onSubmit,
                  icon: Icon(isEditing ? Icons.check : Icons.arrow_upward),
                  tooltip: isEditing ? 'Сохранить' : 'Отправить',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
