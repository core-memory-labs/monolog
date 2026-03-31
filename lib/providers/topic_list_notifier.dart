import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/topic_with_stats.dart';
import 'providers.dart';

/// Manages the list of topics with their stats.
///
/// Every mutation (add, rename, delete, pin toggle, icon change) re-fetches
/// the full list from the database. For a local SQLite database this is
/// near-instant.
class TopicListNotifier extends AsyncNotifier<List<TopicWithStats>> {
  @override
  Future<List<TopicWithStats>> build() {
    return ref.read(databaseServiceProvider).getTopicsWithStats();
  }

  Future<void> addTopic(String title) async {
    final db = ref.read(databaseServiceProvider);
    await db.insertTopic(title.trim());
    ref.invalidateSelf();
    await future;
  }

  Future<void> renameTopic(int id, String newTitle) async {
    final db = ref.read(databaseServiceProvider);
    final topic = await db.getTopicById(id);
    if (topic == null) return;
    await db.updateTopic(topic.copyWith(title: newTitle.trim()));
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteTopic(int id) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteTopic(id);
    ref.invalidateSelf();
    await future;
  }

  Future<void> togglePin(int id, {required bool isPinned}) async {
    final db = ref.read(databaseServiceProvider);
    await db.togglePin(id, isPinned: isPinned);
    ref.invalidateSelf();
    await future;
  }

  /// Updates the topic icon (emoji). Pass `null` to remove the icon.
  Future<void> setTopicIcon(int id, String? icon) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateTopicIcon(id, icon);
    ref.invalidateSelf();
    await future;
  }
}

final topicListProvider =
    AsyncNotifierProvider<TopicListNotifier, List<TopicWithStats>>(
  TopicListNotifier.new,
);
