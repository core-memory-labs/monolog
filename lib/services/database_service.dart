import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/entry.dart';
import '../models/topic.dart';
import '../models/topic_with_stats.dart';

class DatabaseService {
  static const _databaseName = 'monolog.db';
  static const _databaseVersion = 1;

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

    // FTS5 for full-text search will be added in Stage 4
    // together with sqlite3_flutter_libs (Android's built-in SQLite lacks FTS5).
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
