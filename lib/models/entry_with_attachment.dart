import 'entry.dart';
import 'entry_attachment.dart';

/// An [Entry] enriched with its attached files.
///
/// Used by the entry feed screen. The [attachments] list is ordered by
/// [EntryAttachment.sortOrder]. The UI expects at most one attachment.
class EntryWithAttachment {
  final Entry entry;
  final List<EntryAttachment> attachments;

  const EntryWithAttachment({
    required this.entry,
    this.attachments = const [],
  });

  /// First attachment or `null`.
  EntryAttachment? get firstAttachment =>
      attachments.isNotEmpty ? attachments.first : null;

  /// Convenience getter: first file path or `null`.
  String? get firstFilePath => firstAttachment?.filePath;

  /// Whether the first attachment is an image.
  bool get hasImage => firstAttachment?.isImage ?? false;

  /// Whether the first attachment is a non-image file.
  bool get hasFile => firstAttachment != null && !firstAttachment!.isImage;
}
