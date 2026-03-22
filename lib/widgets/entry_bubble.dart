import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/entry.dart';
import '../utils/date_format.dart';

/// Displays a single entry in the feed.
///
/// Recognises URLs in [entry.content] and renders them as tappable links.
/// Shows the creation timestamp below the text.
/// When [isSelected] is true the background is highlighted.
class EntryBubble extends StatelessWidget {
  final Entry entry;
  final bool isSelected;
  final VoidCallback? onLongPress;

  const EntryBubble({
    super.key,
    required this.entry,
    this.isSelected = false,
    this.onLongPress,
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
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodyLarge,
                children: _buildSpans(context),
              ),
            ),
            const SizedBox(height: 4),
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
    final text = entry.content;
    final spans = <TextSpan>[];
    final matches = _urlRegex.allMatches(text);
    int lastEnd = 0;

    for (final match in matches) {
      // Plain text before this URL.
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

    // Remaining plain text.
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    // Safety: ensure at least one span.
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }

    return spans;
  }
}
