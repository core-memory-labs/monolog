import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/entry.dart';
import '../providers/topic_list_notifier.dart';
import '../services/providers.dart';

/// Manages entries for a single topic.
///
/// Family parameter is the topic ID. Every mutation re-fetches from the
/// database and also invalidates [topicListProvider] so the topic list
/// reflects updated entry counts and last-activity dates.
class EntryListNotifier extends FamilyAsyncNotifier<List<Entry>, int> {
  @override
  Future<List<Entry>> build(int arg) {
    return ref.read(databaseServiceProvider).getEntries(arg);
  }

  int get _topicId => arg;

  Future<void> addEntry(String content) async {
    final db = ref.read(databaseServiceProvider);
    await db.insertEntry(topicId: _topicId, content: content.trim());
    ref.invalidateSelf();
    await future;
    ref.invalidate(topicListProvider);
  }

  Future<void> updateEntry(int entryId, String newContent) async {
    final db = ref.read(databaseServiceProvider);
    final entries = state.valueOrNull;
    if (entries == null) return;

    final entry = entries.firstWhere((e) => e.id == entryId);
    await db.updateEntry(entry.copyWith(content: newContent.trim()));
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteEntry(int entryId) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteEntry(entryId);
    ref.invalidateSelf();
    await future;
    ref.invalidate(topicListProvider);
  }
}

final entryListProvider =
    AsyncNotifierProvider.family<EntryListNotifier, List<Entry>, int>(
  EntryListNotifier.new,
);
