import 'package:flutter/material.dart';

import '../models/entry_attachment.dart';
import '../utils/file_utils.dart';

/// Displays a non-image file attachment as a compact card.
///
/// Shows: file-type icon (based on MIME type), file name, and file size.
/// [onTap] opens the file with the system app. [onRemove] shows a close
/// button (used in the input field during editing).
class FileCard extends StatelessWidget {
  final EntryAttachment? attachment;

  /// Alternative constructor data for use in input preview (before saving).
  final String? fileName;
  final int? fileSize;
  final String? mimeType;

  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const FileCard({
    super.key,
    this.attachment,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final displayName =
        attachment?.fileName ?? fileName ?? 'Файл';
    final displaySize =
        formatFileSize(attachment?.fileSize ?? fileSize);
    final displayMimeType =
        attachment?.mimeType ?? mimeType;
    final icon = iconForMimeType(displayMimeType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // File type icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 22,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),

            // Name + size
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (displaySize.isNotEmpty)
                    Text(
                      displaySize,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),

            // Remove button (only in edit/input mode)
            if (onRemove != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
