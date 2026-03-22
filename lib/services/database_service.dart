import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/entry.dart';
import '../models/entry_attachment.dart';
import '../models/entry_with_attachment.dart';
import '../models/topic.dart';
import '../models/topic_with_stats.dart';

class DatabaseService {
  static const _databaseName = 'monolog.db';
  static const _databaseVersion = 3;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final path = join(documentsDir.path, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE topics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (topic_id) REFERENCES topics (id) ON DELETE CASCADE
      )
    ''');

    await _createEntryAttachmentsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 had no attachments table. Create the final schema directly —
      // skip the intermediate entry_images table from v2.
      await _createEntryAttachmentsTable(db);
    } else if (oldVersion < 3) {
      // v2 had entry_images. Rename and add new columns.
      await db.execute('ALTER TABLE entry_images RENAME TO entry_attachments');
      await db.execute(
          'ALTER TABLE entry_attachments ADD COLUMN file_name TEXT');
      await db.execute(
          'ALTER TABLE entry_attachments ADD COLUMN file_size INTEGER');
      await db.execute(
          'ALTER TABLE entry_attachments ADD COLUMN mime_type TEXT');
    }
  }

  /// Creates the `entry_attachments` table with all columns (v3 schema).
  Future<void> _createEntryAttachmentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE entry_attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id INTEGER NOT NULL,
        image_path TEXT NOT NULL,
        media_type TEXT NOT NULL DEFAULT 'image',
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        file_name TEXT,
        file_size INTEGER,
        mime_type TEXT,
        FOREIGN KEY (entry_id) REFERENCES entries (id) ON DELETE CASCADE
      )
    ''');
  }

  // ---------------------------------------------------------------------------
  // Topics CRUD
  // ---------------------------------------------------------------------------

  Future<Topic> insertTopic(String title) async {
    final db = await database;
    final now = DateTime.now();
    final topic = Topic(
      title: title,
      createdAt: now,
      updatedAt: now,
    );
    final id = await db.insert('topics', topic.toMap());
    return topic.copyWith(id: id);
  }

  /// Returns topics sorted: pinned first, then by latest entry date (or
  /// topic.updated_at when no entries exist).
  Future<List<Topic>> getTopics() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT t.*,
             COALESCE(MAX(e.created_at), t.updated_at) AS last_activity
        FROM topics t
        LEFT JOIN entries e ON e.topic_id = t.id
       GROUP BY t.id
       ORDER BY t.is_pinned DESC, last_activity DESC
    ''');
    return rows.map((row) => Topic.fromMap(row)).toList();
  }

  /// Returns topics with entry count and last activity — used by the topic
  /// list screen.
  Future<List<TopicWithStats>> getTopicsWithStats() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT t.*,
             COALESCE(MAX(e.created_at), t.updated_at) AS last_activity,
             COUNT(e.id) AS entry_count
        FROM topics t
        LEFT JOIN entries e ON e.topic_id = t.id
       GROUP BY t.id
       ORDER BY t.is_pinned DESC, last_activity DESC
    ''');
    return rows.map((row) {
      return TopicWithStats(
        topic: Topic.fromMap(row),
        entryCount: row['entry_count'] as int,
        lastActivity: DateTime.parse(row['last_activity'] as String),
      );
    }).toList();
  }

  Future<Topic?> getTopicById(int id) async {
    final db = await database;
    final rows = await db.query('topics', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Topic.fromMap(rows.first);
  }

  Future<void> updateTopic(Topic topic) async {
    final db = await database;
    final updated = topic.copyWith(updatedAt: DateTime.now());
    await db.update(
      'topics',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [topic.id],
    );
  }

  Future<void> deleteTopic(int id) async {
    final db = await database;
    await db.delete('topics', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> togglePin(int id, {required bool isPinned}) async {
    final db = await database;
    await db.update(
      'topics',
      {
        'is_pinned': isPinned ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Entries CRUD
  // ---------------------------------------------------------------------------

  Future<Entry> insertEntry({
    required int topicId,
    required String content,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final entry = Entry(
      topicId: topicId,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    final id = await db.insert('entries', entry.toMap());
    return entry.copyWith(id: id);
  }

  /// Returns entries for a topic, newest first.
  Future<List<Entry>> getEntries(int topicId) async {
    final db = await database;
    final rows = await db.query(
      'entries',
      where: 'topic_id = ?',
      whereArgs: [topicId],
      orderBy: 'created_at DESC',
    );
    return rows.map((row) => Entry.fromMap(row)).toList();
  }

  /// Returns entries for a topic with their attachments, newest first.
  ///
  /// Uses two queries: one for entries, one for all attachments of those
  /// entries. This avoids N+1 and is efficient for local SQLite.
  Future<List<EntryWithAttachment>> getEntriesWithAttachments(
      int topicId) async {
    final db = await database;

    final entryRows = await db.query(
      'entries',
      where: 'topic_id = ?',
      whereArgs: [topicId],
      orderBy: 'created_at DESC',
    );

    if (entryRows.isEmpty) return [];

    // Fetch all attachments for this topic's entries in one query.
    final entryIds = entryRows.map((r) => r['id'] as int).toList();
    final placeholders = entryIds.map((_) => '?').join(',');
    final attachmentRows = await db.rawQuery(
      'SELECT * FROM entry_attachments WHERE entry_id IN ($placeholders) ORDER BY sort_order ASC',
      entryIds,
    );

    // Group attachments by entry_id.
    final attachmentsByEntry = <int, List<EntryAttachment>>{};
    for (final row in attachmentRows) {
      final entryId = row['entry_id'] as int;
      attachmentsByEntry
          .putIfAbsent(entryId, () => [])
          .add(EntryAttachment.fromMap(row));
    }

    return entryRows.map((row) {
      final entry = Entry.fromMap(row);
      return EntryWithAttachment(
        entry: entry,
        attachments: attachmentsByEntry[entry.id] ?? [],
      );
    }).toList();
  }

  Future<void> updateEntry(Entry entry) async {
    final db = await database;
    final updated = entry.copyWith(updatedAt: DateTime.now());
    await db.update(
      'entries',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteEntry(int id) async {
    final db = await database;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  /// Returns the number of entries in a topic.
  Future<int> getEntryCount(int topicId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM entries WHERE topic_id = ?',
      [topicId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Entry Attachments CRUD
  // ---------------------------------------------------------------------------

  Future<EntryAttachment> insertEntryAttachment({
    required int entryId,
    required String filePath,
    required String mediaType,
    int sortOrder = 0,
    String? fileName,
    int? fileSize,
    String? mimeType,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final attachment = EntryAttachment(
      entryId: entryId,
      filePath: filePath,
      mediaType: mediaType,
      sortOrder: sortOrder,
      createdAt: now,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
    );
    final id = await db.insert('entry_attachments', attachment.toMap());
    return attachment.copyWith(id: id);
  }

  /// Returns all attachments for an entry, ordered by sort_order.
  Future<List<EntryAttachment>> getEntryAttachments(int entryId) async {
    final db = await database;
    final rows = await db.query(
      'entry_attachments',
      where: 'entry_id = ?',
      whereArgs: [entryId],
      orderBy: 'sort_order ASC',
    );
    return rows.map((row) => EntryAttachment.fromMap(row)).toList();
  }

  /// Deletes all attachments for an entry from the database.
  /// Note: caller is responsible for deleting the actual files from disk.
  Future<void> deleteEntryAttachments(int entryId) async {
    final db = await database;
    await db.delete(
      'entry_attachments',
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
