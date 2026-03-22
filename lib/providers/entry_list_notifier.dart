import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/entry_with_images.dart';
import '../providers/topic_list_notifier.dart';
import 'providers.dart';

/// Manages entries (with images) for a single topic.
///
/// Family parameter is the topic ID. Every mutation re-fetches from the
/// database and also invalidates [topicListProvider] so the topic list
/// reflects updated entry counts and last-activity dates.
class EntryListNotifier extends FamilyAsyncNotifier<List<EntryWithImages>, int> {
  @override
  Future<List<EntryWithImages>> build(int arg) {
    return ref.read(databaseServiceProvider).getEntriesWithImages(arg);
  }

  int get _topicId => arg;

  /// Creates a new entry with optional image attachment.
  Future<void> addEntry(String content, {String? imagePath}) async {
    final db = ref.read(databaseServiceProvider);
    final imageService = ref.read(imageServiceProvider);

    final entry = await db.insertEntry(
      topicId: _topicId,
      content: content.trim(),
    );

    if (imagePath != null) {
      final savedPath = await imageService.saveImage(imagePath);
      await db.insertEntryImage(
        entryId: entry.id!,
        imagePath: savedPath,
        mediaType: 'image',
      );
    }

    ref.invalidateSelf();
    await future;
    ref.invalidate(topicListProvider);
  }

  /// Updates an existing entry's text and optionally modifies its image.
  ///
  /// - [newImagePath] non-null → attach or replace image.
  /// - [removeImage] true → delete existing image(s) from disk and DB.
  /// - Both set → replace (old deleted, new saved).
  Future<void> updateEntry(
    int entryId,
    String newContent, {
    String? newImagePath,
    bool removeImage = false,
  }) async {
    final db = ref.read(databaseServiceProvider);
    final imageService = ref.read(imageServiceProvider);
    final entries = state.valueOrNull;
    if (entries == null) return;

    final data = entries.firstWhere((e) => e.entry.id == entryId);
    await db.updateEntry(data.entry.copyWith(content: newContent.trim()));

    // Handle image changes.
    if (removeImage) {
      for (final img in data.images) {
        await imageService.deleteImage(img.imagePath);
      }
      await db.deleteEntryImages(entryId);
    }

    if (newImagePath != null) {
      final savedPath = await imageService.saveImage(newImagePath);
      await db.insertEntryImage(
        entryId: entryId,
        imagePath: savedPath,
        mediaType: 'image',
      );
    }

    ref.invalidateSelf();
    await future;
  }

  /// Deletes an entry and its image files from disk.
  Future<void> deleteEntry(int entryId) async {
    final db = ref.read(databaseServiceProvider);
    final imageService = ref.read(imageServiceProvider);

    // Delete image files before removing DB records (cascade will delete
    // entry_images rows, so we need the paths first).
    final images = await db.getEntryImages(entryId);
    for (final img in images) {
      await imageService.deleteImage(img.imagePath);
    }

    await db.deleteEntry(entryId);
    ref.invalidateSelf();
    await future;
    ref.invalidate(topicListProvider);
  }
}

final entryListProvider =
    AsyncNotifierProvider.family<EntryListNotifier, List<EntryWithImages>, int>(
  EntryListNotifier.new,
);
