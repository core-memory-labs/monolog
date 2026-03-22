/// Lightweight Markdown parser for Monolog entries.
///
/// Supports a Telegram-inspired subset:
/// - **Bold**: `*text*` or `**text**`
/// - *Italic*: `_text_`
/// - ~~Strikethrough~~: `~text~`
/// - `Inline code`: `` `text` ``
/// - Code block: ` ``` ` (multiline, monospace)
/// - Quote: `> text` (line-level)
/// - URL detection: `https://...` or `http://...`
///
/// No nested formatting — only one level of inline styling is applied.
/// Block-level elements (code block, quote) are parsed first, then inline
/// formatting is applied to paragraph and quote content.

// ---------------------------------------------------------------------------
// Data structures
// ---------------------------------------------------------------------------

/// Visual style for an inline text span.
enum InlineStyle { plain, bold, italic, strikethrough, code, url }

/// A single styled run of text within a paragraph or quote block.
class StyledSpan {
  final InlineStyle style;
  final String text;
  const StyledSpan(this.style, this.text);

  @override
  String toString() => 'StyledSpan($style, "$text")';
}

/// The kind of top-level block produced by the parser.
enum BlockType { paragraph, codeBlock, quote }

/// A parsed block of content. Either a paragraph (with inline spans),
/// a code block (raw text), or a quote (with inline spans).
class MarkdownBlock {
  final BlockType type;

  /// Raw text content — used for [BlockType.codeBlock].
  final String rawContent;

  /// Parsed inline spans — used for [BlockType.paragraph] and
  /// [BlockType.quote].
  final List<StyledSpan> spans;

  const MarkdownBlock._({
    required this.type,
    this.rawContent = '',
    this.spans = const [],
  });

  factory MarkdownBlock.paragraph(List<StyledSpan> spans) =>
      MarkdownBlock._(type: BlockType.paragraph, spans: spans);

  factory MarkdownBlock.codeBlock(String content) =>
      MarkdownBlock._(type: BlockType.codeBlock, rawContent: content);

  factory MarkdownBlock.quote(List<StyledSpan> spans) =>
      MarkdownBlock._(type: BlockType.quote, spans: spans);
}

// ---------------------------------------------------------------------------
// Regex patterns
// ---------------------------------------------------------------------------

/// Matches http / https URLs, stopping before trailing punctuation.
final _urlRegex = RegExp(
  r'https?://[^\s<>\[\]{}|\\^`"]+[^\s<>\[\]{}|\\^`".,;:!?\-)]',
  caseSensitive: false,
);

/// Fenced code block: ``` optionally followed by a language id, content, ```.
final _codeBlockRegex = RegExp(r'```[^\n]*\n?([\s\S]*?)```');

/// Inline formatting — order matters (first match wins at each position):
///   1. inline code (backticks protect content from further parsing)
///   2. bold **…**
///   3. bold *…*
///   4. italic _…_
///   5. strikethrough ~…~
final _inlineRegex = RegExp(
  r'`([^`\n]+)`' // Group 1: inline code
  r'|\*\*(.+?)\*\*' // Group 2: bold **
  r'|\*(.+?)\*' // Group 3: bold *
  r'|_(.+?)_' // Group 4: italic
  r'|~(.+?)~', // Group 5: strikethrough
);

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Parses [input] into a list of [MarkdownBlock]s.
///
/// Code blocks are extracted first (they are opaque — no inline parsing
/// inside). The remaining text is split into paragraphs and quotes, each
/// with inline formatting applied.
List<MarkdownBlock> parseMarkdown(String input) {
  if (input.isEmpty) return [];

  final blocks = <MarkdownBlock>[];
  int lastEnd = 0;

  // 1. Extract fenced code blocks.
  for (final match in _codeBlockRegex.allMatches(input)) {
    // Text before the code block.
    if (match.start > lastEnd) {
      blocks.addAll(_parseTextIntoBlocks(input.substring(lastEnd, match.start)));
    }

    final code = (match.group(1) ?? '').trimRight();
    if (code.isNotEmpty) {
      blocks.add(MarkdownBlock.codeBlock(code));
    }

    lastEnd = match.end;
  }

  // 2. Remaining text after the last code block (or the whole string).
  if (lastEnd < input.length) {
    blocks.addAll(_parseTextIntoBlocks(input.substring(lastEnd)));
  }

  return blocks;
}

/// Extracts the first http/https URL found in [text], or `null` if none.
///
/// Used by [LinkPreviewCard] to determine which URL to preview.
/// Reuses the same regex as inline URL detection.
String? extractFirstUrl(String text) {
  if (text.isEmpty) return null;
  final match = _urlRegex.firstMatch(text);
  return match?.group(0);
}

/// Strips Markdown formatting markers from [content], returning plain text.
///
/// Used for search result snippets where formatting markers would be
/// distracting. Removes code blocks, inline markers (`*`, `_`, `~`, `` ` ``),
/// and quote prefixes (`> `).
String stripMarkdown(String content) {
  return content
      .replaceAll(_codeBlockRegex, ' ') // remove code blocks
      .replaceAll(RegExp(r'[*_~`]'), '') // remove inline markers
      .replaceAll(RegExp(r'^> ', multiLine: true), '') // remove quote prefix
      .replaceAll(RegExp(r'\s+'), ' ') // normalise whitespace
      .trim();
}

// ---------------------------------------------------------------------------
// Block-level parsing (quotes vs. paragraphs)
// ---------------------------------------------------------------------------

/// Splits non-code text into [BlockType.paragraph] and [BlockType.quote]
/// blocks by detecting `> ` prefix on each line.
List<MarkdownBlock> _parseTextIntoBlocks(String text) {
  if (text.trim().isEmpty) return [];

  final lines = text.split('\n');
  final blocks = <MarkdownBlock>[];

  final buffer = <String>[];
  bool bufferIsQuote = false;

  void flushBuffer() {
    if (buffer.isEmpty) return;
    final content = buffer.join('\n').trim();
    if (content.isEmpty) {
      buffer.clear();
      return;
    }
    final spans = _parseInline(content);
    blocks.add(
      bufferIsQuote
          ? MarkdownBlock.quote(spans)
          : MarkdownBlock.paragraph(spans),
    );
    buffer.clear();
  }

  for (final line in lines) {
    final isQuote = line.startsWith('> ');

    if (buffer.isEmpty) {
      bufferIsQuote = isQuote;
      buffer.add(isQuote ? line.substring(2) : line);
    } else if (isQuote == bufferIsQuote) {
      buffer.add(isQuote ? line.substring(2) : line);
    } else {
      flushBuffer();
      bufferIsQuote = isQuote;
      buffer.add(isQuote ? line.substring(2) : line);
    }
  }

  flushBuffer();
  return blocks;
}

// ---------------------------------------------------------------------------
// Inline parsing
// ---------------------------------------------------------------------------

/// Parses inline formatting within a text segment.
///
/// URLs are detected first (they take priority over `_` in italic detection),
/// then inline markdown is applied to non-URL parts.
List<StyledSpan> _parseInline(String text) {
  if (text.isEmpty) return [];

  final spans = <StyledSpan>[];
  int lastEnd = 0;

  // 1. Find URLs first — they have priority.
  for (final urlMatch in _urlRegex.allMatches(text)) {
    // Parse inline formatting in the segment before this URL.
    if (urlMatch.start > lastEnd) {
      spans.addAll(
        _parseInlineFormatting(text.substring(lastEnd, urlMatch.start)),
      );
    }
    spans.add(StyledSpan(InlineStyle.url, urlMatch.group(0)!));
    lastEnd = urlMatch.end;
  }

  // 2. Parse inline formatting in the remaining text.
  if (lastEnd < text.length) {
    spans.addAll(_parseInlineFormatting(text.substring(lastEnd)));
  }

  if (spans.isEmpty) {
    spans.add(StyledSpan(InlineStyle.plain, text));
  }

  return spans;
}

/// Applies inline formatting regex to a URL-free text segment.
List<StyledSpan> _parseInlineFormatting(String text) {
  if (text.isEmpty) return [];

  final spans = <StyledSpan>[];
  int lastEnd = 0;

  for (final match in _inlineRegex.allMatches(text)) {
    // Plain text before this match.
    if (match.start > lastEnd) {
      spans.add(StyledSpan(InlineStyle.plain, text.substring(lastEnd, match.start)));
    }

    if (match.group(1) != null) {
      spans.add(StyledSpan(InlineStyle.code, match.group(1)!));
    } else if (match.group(2) != null) {
      spans.add(StyledSpan(InlineStyle.bold, match.group(2)!));
    } else if (match.group(3) != null) {
      spans.add(StyledSpan(InlineStyle.bold, match.group(3)!));
    } else if (match.group(4) != null) {
      spans.add(StyledSpan(InlineStyle.italic, match.group(4)!));
    } else if (match.group(5) != null) {
      spans.add(StyledSpan(InlineStyle.strikethrough, match.group(5)!));
    }

    lastEnd = match.end;
  }

  // Trailing plain text.
  if (lastEnd < text.length) {
    spans.add(StyledSpan(InlineStyle.plain, text.substring(lastEnd)));
  }

  return spans;
}
