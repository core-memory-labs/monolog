import '../models/entry.dart';
import '../models/entry_attachment.dart';
import '../models/entry_with_attachment.dart';
import '../models/link_preview.dart';
import '../models/search_result.dart';
import '../models/topic.dart';
import '../models/topic_with_stats.dart';

/// Abstract interface for Monolog's data persistence layer.
///
/// Defines all CRUD operations for topics, entries, attachments, link previews,
/// and full-text search. The concrete implementation ([SqliteDatabaseService])
/// uses SQLite via `sqflite_common_ffi`.
///
/// Extracted as an abstract class to allow mock implementations in unit tests.
abstract class DatabaseService {
  /// Initialises the database (e.g. opens connection, runs migrations).
  ///
  /// Must be called once before any other method. In production this is
  /// called eagerly in `main.dart`.
  Future<void> init();

  /// Closes the database connection and releases resources.
  Future<void> close();

  // ---------------------------------------------------------------------------
  // Topics CRUD
  // ---------------------------------------------------------------------------

  /// Creates a new topic with [title] and returns it with the assigned ID.
  Future<Topic> insertTopic(String title);

  /// Returns all topics sorted: pinned first, then by latest entry date.
  Future<List<Topic>> getTopics();

  /// Returns all topics with entry count and last activity.
  Future<List<TopicWithStats>> getTopicsWithStats();

  /// Returns the topic with [id], or `null` if not found.
  Future<Topic?> getTopicById(int id);

  /// Updates [topic] fields and sets `updated_at` to now.
  Future<void> updateTopic(Topic topic);

  /// Deletes the topic with [id] and all its entries (CASCADE).
  Future<void> deleteTopic(int id);

  /// Pins or unpins the topic with [id].
  Future<void> togglePin(int id, {required bool isPinned});

  // ---------------------------------------------------------------------------
  // Entries CRUD
  // ---------------------------------------------------------------------------

  /// Creates a new entry in the given topic. If [createdAt] is provided,
  /// it overrides the default `DateTime.now()` — used for preserving
  /// original dates during import.
  Future<Entry> insertEntry({
    required int topicId,
    required String content,
    DateTime? createdAt,
  });

  /// Returns entries for a topic, newest first.
  Future<List<Entry>> getEntries(int topicId);

  /// Returns entries for a topic with their attachments, newest first.
  Future<List<EntryWithAttachment>> getEntriesWithAttachments(int topicId);

  /// Updates [entry] fields and sets `updated_at` to now.
  Future<void> updateEntry(Entry entry);

  /// Deletes the entry with [id]. Attachments are deleted via CASCADE.
  Future<void> deleteEntry(int id);

  // ---------------------------------------------------------------------------
  // Entry Attachments CRUD
  // ---------------------------------------------------------------------------

  /// Creates an attachment record for the given entry.
  Future<EntryAttachment> insertEntryAttachment({
    required int entryId,
    required String filePath,
    String mediaType = 'image',
    String? fileName,
    int? fileSize,
    String? mimeType,
  });

  /// Returns all attachments for a given entry.
  Future<List<EntryAttachment>> getEntryAttachments(int entryId);

  /// Deletes all attachment records for an entry.
  /// Note: caller is responsible for deleting the actual files from disk.
  Future<void> deleteEntryAttachments(int entryId);

  // ---------------------------------------------------------------------------
  // Link Previews CRUD
  // ---------------------------------------------------------------------------

  /// Returns the cached link preview for [url], or `null` if not cached.
  Future<LinkPreview?> getLinkPreview(String url);

  /// Inserts or replaces a link preview cache entry.
  Future<LinkPreview> insertLinkPreview({
    required String url,
    String? title,
    String? description,
    String? imageUrl,
    String? imagePath,
    String? siteName,
  });

  /// Deletes the cached link preview for [url].
  Future<void> deleteLinkPreview(String url);

  // ---------------------------------------------------------------------------
  // Full-text search (FTS5)
  // ---------------------------------------------------------------------------

  /// Searches entries by content using full-text search.
  ///
  /// Returns results ranked by relevance, limited to 50 entries.
  Future<List<SearchResult>> searchEntries(String query);
}
