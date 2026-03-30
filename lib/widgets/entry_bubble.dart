import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/entry_with_attachment.dart';
import '../utils/date_format.dart';
import '../utils/markdown_parser.dart';
import 'file_card.dart';
import 'link_preview_card.dart';

/// Displays a single entry in the feed.
///
/// Shows an optional image preview or file card, parses Markdown formatting
/// in content, recognises URLs as tappable links, shows a link preview card
/// for the first URL, and shows the creation timestamp.
///
/// [isSelected] highlights the entry for the contextual AppBar selection.
/// [isHighlighted] briefly highlights the entry when scrolled to from search.
/// [onTap] is used in multi-selection mode to toggle selection on regular tap.
class EntryBubble extends StatelessWidget {
  final EntryWithAttachment data;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onImageTap;
  final VoidCallback? onFileTap;

  const EntryBubble({
    super.key,
    required this.data,
    this.isSelected = false,
    this.isHighlighted = false,
    this.onTap,
    this.onLongPress,
    this.onImageTap,
    this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = data.entry;
    final hasContent = entry.content.isNotEmpty;

    // Extract the first URL for link preview.
    final firstUrl = hasContent ? extractFirstUrl(entry.content) : null;

    // Determine background colour: selection takes priority over highlight.
    Color bgColor;
    if (isSelected) {
      bgColor = theme.colorScheme.primaryContainer.withValues(alpha: 0.3);
    } else if (isHighlighted) {
      bgColor = theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3);
    } else {
      bgColor = Colors.transparent;
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: bgColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview
            if (data.hasImage && data.firstFilePath != null)
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
                          File(data.firstFilePath!),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 100,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child:
                                  Icon(Icons.broken_image_outlined, size: 32),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // File card (non-image attachment)
            if (data.hasFile && data.firstAttachment != null)
              Padding(
                padding: EdgeInsets.only(bottom: hasContent ? 8 : 4),
                child: FileCard(
                  attachment: data.firstAttachment!,
                  onTap: onFileTap,
                ),
              ),

            // Formatted text content (skip if empty — attachment-only entry)
            if (hasContent) ..._buildContent(context),

            // Link preview card (for the first URL in content)
            if (firstUrl != null)
              Padding(
                padding: EdgeInsets.only(top: hasContent ? 6 : 0, bottom: 4),
                child: LinkPreviewCard(url: firstUrl),
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

  // ---------------------------------------------------------------------------
  // Markdown rendering
  // ---------------------------------------------------------------------------

  /// Parses the entry content as Markdown and returns a list of widgets —
  /// one per block (paragraph, code block, or quote).
  List<Widget> _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = parseMarkdown(data.entry.content);
    if (blocks.isEmpty) return [];

    final widgets = <Widget>[];

    for (int i = 0; i < blocks.length; i++) {
      if (i > 0) widgets.add(const SizedBox(height: 6));

      switch (blocks[i].type) {
        case BlockType.paragraph:
          widgets.add(
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodyLarge,
                children: _inlineSpansToTextSpans(blocks[i].spans, theme),
              ),
            ),
          );
        case BlockType.codeBlock:
          widgets.add(_buildCodeBlock(blocks[i].rawContent, theme));
        case BlockType.quote:
          widgets.add(_buildQuoteBlock(blocks[i].spans, theme));
      }
    }

    return widgets;
  }

  /// Renders a fenced code block as a monospace container.
  static Widget _buildCodeBlock(String code, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          code,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  /// Renders a quote block with a coloured left border.
  static Widget _buildQuoteBlock(List<StyledSpan> spans, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyLarge?.copyWith(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          children: _inlineSpansToTextSpans(spans, theme),
        ),
      ),
    );
  }

  /// Converts parser [StyledSpan]s into Flutter [TextSpan]s with the
  /// appropriate styles and gesture recognisers.
  static List<TextSpan> _inlineSpansToTextSpans(
    List<StyledSpan> spans,
    ThemeData theme,
  ) {
    return spans.map((span) {
      return switch (span.style) {
        InlineStyle.plain => TextSpan(text: span.text),
        InlineStyle.bold => TextSpan(
            text: span.text,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        InlineStyle.italic => TextSpan(
            text: span.text,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        InlineStyle.strikethrough => TextSpan(
            text: span.text,
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ),
        InlineStyle.code => TextSpan(
            text: span.text,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        InlineStyle.url => TextSpan(
            text: span.text,
            style: TextStyle(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                final uri = Uri.tryParse(span.text);
                if (uri != null) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
          ),
      };
    }).toList();
  }
}
