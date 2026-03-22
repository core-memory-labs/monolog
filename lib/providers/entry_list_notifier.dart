import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/entry_with_attachment.dart';
import '../providers/topic_list_notifier.dart';
import 'providers.dart';

/// Manages entries (with attachments) for a single topic.
///
/// Family parameter is the topic ID. Every mutation re-fetches from the
/// database and also invalidates [topicListProvider] so the topic list
/// reflects updated entry counts and last-activity dates.
class EntryListNotifier
    extends FamilyAsyncNotifier<List<EntryWithAttachment>, int> {
  @override
  Future<List<EntryWithAttachment>> build(int arg) {
    return ref.read(databaseServiceProvider).getEntriesWithAttachments(arg);
  }

  int get _topicId => arg;

  /// Creates a new entry with an optional file attachment.
  ///
  /// For images: [mediaType] should be `'image'`.
  /// For other files: [mediaType] should be `'file'`.
  Future<void> addEntry(
    String content, {
    String? filePath,
    String mediaType = 'image',
    String? fileName,
    int? fileSize,
    String? mimeType,
  }) async {
    final db = ref.read(databaseServiceProvider);
    final fileService = ref.read(fileServiceProvider);

    final entry = await db.insertEntry(
      topicId: _topicId,
      content: content.trim(),
    );

    if (filePath != null) {
      final savedPath =
          await fileService.saveFile(filePath, fileName: fileName);
      await db.insertEntryAttachment(
        entryId: entry.id!,
        filePath: savedPath,
        mediaType: mediaType,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
      );
    }

    ref.invalidateSelf();
    await future;
    ref.invalidate(topicListProvider);
  }

  /// Updates an existing entry's text and optionally modifies its attachment.
  ///
  /// - [newFilePath] non-null → attach or replace file.
  /// - [removeAttachment] true → delete existing attachment(s) from disk & DB.
  /// - Both set → replace (old deleted, new saved).
  Future<void> updateEntry(
    int entryId,
    String newContent, {
    String? newFilePath,
    bool removeAttachment = false,
    String mediaType = 'image',
    String? fileName,
    int? fileSize,
    String? mimeType,
  }) async {
    final db = ref.read(databaseServiceProvider);
    final fileService = ref.read(fileServiceProvider);
    final entries = state.valueOrNull;
    if (entries == null) return;

    final data = entries.firstWhere((e) => e.entry.id == entryId);
    await db.updateEntry(data.entry.copyWith(content: newContent.trim()));

    // Handle attachment changes.
    if (removeAttachment) {
      for (final att in data.attachments) {
        await fileService.deleteFile(att.filePath);
      }
      await db.deleteEntryAttachments(entryId);
    }

    if (newFilePath != null) {
      final savedPath =
          await fileService.saveFile(newFilePath, fileName: fileName);
      await db.insertEntryAttachment(
        entryId: entryId,
        filePath: savedPath,
        mediaType: mediaType,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
      );
    }

    ref.invalidateSelf();
    await future;
  }

  /// Deletes an entry and its attachment files from disk.
  Future<void> deleteEntry(int entryId) async {
    final db = ref.read(databaseServiceProvider);
    final fileService = ref.read(fileServiceProvider);

    // Delete files before removing DB records (cascade will delete
    // entry_attachments rows, so we need the paths first).
    final attachments = await db.getEntryAttachments(entryId);
    for (final att in attachments) {
      await fileService.deleteFile(att.filePath);
    }

    await db.deleteEntry(entryId);
    ref.invalidateSelf();
    await future;
    ref.invalidate(topicListProvider);
  }
}

final entryListProvider = AsyncNotifierProvider.family<EntryListNotifier,
    List<EntryWithAttachment>, int>(
  EntryListNotifier.new,
);
