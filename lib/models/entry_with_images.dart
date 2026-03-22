import 'entry.dart';
import 'entry_image.dart';

/// An [Entry] enriched with its attached images.
///
/// Used by the entry feed screen. The [images] list is ordered by
/// [EntryImage.sortOrder]. Stage 3.1 UI expects at most one image.
class EntryWithImages {
  final Entry entry;
  final List<EntryImage> images;

  const EntryWithImages({
    required this.entry,
    this.images = const [],
  });

  /// Convenience getter: first image path or `null`.
  String? get firstImagePath => images.isNotEmpty ? images.first.imagePath : null;
}
