import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/entry_with_images.dart';
import '../utils/date_format.dart';

/// Displays a single entry in the feed.
///
/// Shows an optional image preview, recognises URLs in content, and renders
/// them as tappable links. Shows the creation timestamp below.
/// When [isSelected] is true the background is highlighted.
class EntryBubble extends StatelessWidget {
  final EntryWithImages data;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onImageTap;

  const EntryBubble({
    super.key,
    required this.data,
    this.isSelected = false,
    this.onLongPress,
    this.onImageTap,
  });

  /// Matches http / https URLs, stopping before trailing punctuation that is
  /// unlikely to be part of the URL itself.
  static final _urlRegex = RegExp(
    r'https?://[^\s<>\[\]{}|\\^`"]+[^\s<>\[\]{}|\\^`".,;:!?\-)]',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = data.entry;
    final imagePath = data.firstImagePath;
    final hasContent = entry.content.isNotEmpty;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview
            if (imagePath != null)
              Padding(
                padding: EdgeInsets.only(bottom: hasContent ? 8 : 4),
                child: GestureDetector(
                  onTap: onImageTap,
                  child: Hero(
                    tag: 'entry_image_${entry.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: Image.file(
                          File(imagePath),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 100,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: Icon(Icons.broken_image_outlined, size: 32),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Text content (skip if empty — image-only entry)
            if (hasContent)
              RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyLarge,
                  children: _buildSpans(context),
                ),
              ),
            if (hasContent) const SizedBox(height: 4),

            // Timestamp
            Text(
              formatEntryDate(entry.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _buildSpans(BuildContext context) {
    final theme = Theme.of(context);
    final text = data.entry.content;
    final spans = <TextSpan>[];
    final matches = _urlRegex.allMatches(text);
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }

    return spans;
  }
}
