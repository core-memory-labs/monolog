import 'dart:io';

import 'package:flutter/material.dart';

/// Messenger-style input field at the bottom of the entry feed.
///
/// In normal mode shows a text field with a 📎 button on the left and an
/// "arrow up" send button on the right.
/// In edit mode shows a "Редактирование" banner with cancel (×) and
/// the send button changes to a checkmark.
/// When an image is attached, shows a thumbnail preview above the text field.
class EntryInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final bool isEditing;
  final VoidCallback? onCancelEdit;
  final String? attachedImagePath;
  final VoidCallback? onPickImage;
  final VoidCallback? onRemoveImage;

  const EntryInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    this.isEditing = false,
    this.onCancelEdit,
    this.attachedImagePath,
    this.onPickImage,
    this.onRemoveImage,
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

          // Image preview (when attached)
          if (attachedImagePath != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: Image.file(
                        File(attachedImagePath!),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 80,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: onRemoveImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Text field + buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attach button
                IconButton(
                  onPressed: onPickImage,
                  icon: const Icon(Icons.attach_file),
                  tooltip: 'Прикрепить изображение',
                ),
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
