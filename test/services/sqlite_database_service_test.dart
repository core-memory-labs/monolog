import 'package:flutter_test/flutter_test.dart';
import 'package:monolog/services/sqlite_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late SqliteDatabaseService db;

  setUpAll(() {
    // Initialise FFI-based SQLite for desktop testing.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Create a fresh in-memory database for each test.
    final rawDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 5,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE topics (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              is_pinned INTEGER NOT NULL DEFAULT 0,
              icon TEXT,
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
          await db.execute('''
            CREATE TABLE link_previews (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              url TEXT NOT NULL UNIQUE,
              title TEXT,
              description TEXT,
              image_url TEXT,
              image_path TEXT,
              site_name TEXT,
              fetched_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts
            USING fts5(content, content=entries, content_rowid=id)
          ''');
          await db.execute('''
            CREATE TRIGGER IF NOT EXISTS entries_fts_ai AFTER INSERT ON entries BEGIN
              INSERT INTO entries_fts(rowid, content) VALUES (new.id, new.content);
            END
          ''');
          await db.execute('''
            CREATE TRIGGER IF NOT EXISTS entries_fts_ad AFTER DELETE ON entries BEGIN
              INSERT INTO entries_fts(entries_fts, rowid, content) VALUES('delete', old.id, old.content);
            END
          ''');
          await db.execute('''
            CREATE TRIGGER IF NOT EXISTS entries_fts_au AFTER UPDATE ON entries BEGIN
              INSERT INTO entries_fts(entries_fts, rowid, content) VALUES('delete', old.id, old.content);
              INSERT INTO entries_fts(rowid, content) VALUES (new.id, new.content);
            END
          ''');
        },
      ),
    );
    db = SqliteDatabaseService(database: rawDb);
  });

  tearDown(() async {
    await db.close();
  });

  // =========================================================================
  // Topics
  // =========================================================================

  group('Topics CRUD', () {
    test('insertTopic creates topic and returns it with id', () async {
      final topic = await db.insertTopic('Work');

      expect(topic.id, isNotNull);
      expect(topic.title, 'Work');
      expect(topic.isPinned, isFalse);
    });

    test('getTopics returns all topics', () async {
      await db.insertTopic('A');
      await db.insertTopic('B');

      final topics = await db.getTopics();

      expect(topics.length, 2);
    });

    test('getTopicById returns correct topic', () async {
      final created = await db.insertTopic('Find me');

      final found = await db.getTopicById(created.id!);

      expect(found, isNotNull);
      expect(found!.title, 'Find me');
    });

    test('getTopicById returns null for non-existent id', () async {
      final found = await db.getTopicById(999);

      expect(found, isNull);
    });

    test('updateTopic changes title', () async {
      final topic = await db.insertTopic('Old');

      await db.updateTopic(topic.copyWith(title: 'New'));

      final updated = await db.getTopicById(topic.id!);
      expect(updated!.title, 'New');
    });

    test('deleteTopic removes topic', () async {
      final topic = await db.insertTopic('Delete me');

      await db.deleteTopic(topic.id!);

      final found = await db.getTopicById(topic.id!);
      expect(found, isNull);
    });

    test('togglePin pins and unpins topic', () async {
      final topic = await db.insertTopic('Pinnable');
      expect(topic.isPinned, isFalse);

      await db.togglePin(topic.id!, isPinned: true);
      final pinned = await db.getTopicById(topic.id!);
      expect(pinned!.isPinned, isTrue);

      await db.togglePin(topic.id!, isPinned: false);
      final unpinned = await db.getTopicById(topic.id!);
      expect(unpinned!.isPinned, isFalse);
    });

    test('getTopics sorts pinned first', () async {
      final a = await db.insertTopic('A');
      await db.insertTopic('B');
      await db.togglePin(a.id!, isPinned: true);

      final topics = await db.getTopics();

      expect(topics.first.title, 'A');
      expect(topics.first.isPinned, isTrue);
    });

    test('getTopicsWithStats includes entry count', () async {
      final topic = await db.insertTopic('Stats');
      await db.insertEntry(topicId: topic.id!, content: 'One');
      await db.insertEntry(topicId: topic.id!, content: 'Two');

      final stats = await db.getTopicsWithStats();

      expect(stats.length, 1);
      expect(stats.first.entryCount, 2);
    });
  });

  // =========================================================================
  // Entries
  // =========================================================================

  group('Entries CRUD', () {
    test('insertEntry creates entry and returns it with id', () async {
      final topic = await db.insertTopic('Test');

      final entry =
          await db.insertEntry(topicId: topic.id!, content: 'Hello world');

      expect(entry.id, isNotNull);
      expect(entry.topicId, topic.id);
      expect(entry.content, 'Hello world');
    });

    test('insertEntry preserves custom createdAt', () async {
      final topic = await db.insertTopic('Test');
      final customDate = DateTime(2020, 6, 15, 9, 30);

      final entry = await db.insertEntry(
        topicId: topic.id!,
        content: 'Old',
        createdAt: customDate,
      );

      expect(entry.createdAt, customDate);
    });

    test('getEntries returns entries newest first', () async {
      final topic = await db.insertTopic('Test');
      await db.insertEntry(
        topicId: topic.id!,
        content: 'First',
        createdAt: DateTime(2024, 1, 1),
      );
      await db.insertEntry(
        topicId: topic.id!,
        content: 'Second',
        createdAt: DateTime(2024, 1, 2),
      );

      final entries = await db.getEntries(topic.id!);

      expect(entries.length, 2);
      expect(entries[0].content, 'Second'); // newest first
      expect(entries[1].content, 'First');
    });

    test('updateEntry changes content', () async {
      final topic = await db.insertTopic('Test');
      final entry = await db.insertEntry(topicId: topic.id!, content: 'Old');

      await db.updateEntry(entry.copyWith(content: 'New'));

      final entries = await db.getEntries(topic.id!);
      expect(entries.first.content, 'New');
    });

    test('deleteEntry removes entry', () async {
      final topic = await db.insertTopic('Test');
      final entry = await db.insertEntry(topicId: topic.id!, content: 'Bye');

      await db.deleteEntry(entry.id!);

      final entries = await db.getEntries(topic.id!);
      expect(entries, isEmpty);
    });

    test('deleteTopic cascades to entries', () async {
      final topic = await db.insertTopic('Cascade');
      await db.insertEntry(topicId: topic.id!, content: 'Child 1');
      await db.insertEntry(topicId: topic.id!, content: 'Child 2');

      await db.deleteTopic(topic.id!);

      // Entries for deleted topic should be gone.
      final entries = await db.getEntries(topic.id!);
      expect(entries, isEmpty);
    });
  });

  // =========================================================================
  // Attachments
  // =========================================================================

  group('Attachments CRUD', () {
    test('insertEntryAttachment creates attachment and returns it', () async {
      final topic = await db.insertTopic('Test');
      final entry = await db.insertEntry(topicId: topic.id!, content: '');

      final att = await db.insertEntryAttachment(
        entryId: entry.id!,
        filePath: '/path/photo.jpg',
        mediaType: 'image',
        fileName: 'photo.jpg',
        fileSize: 1024,
        mimeType: 'image/jpeg',
      );

      expect(att.id, isNotNull);
      expect(att.entryId, entry.id);
      expect(att.filePath, '/path/photo.jpg');
      expect(att.mediaType, 'image');
      expect(att.fileName, 'photo.jpg');
    });

    test('getEntryAttachments returns attachments for entry', () async {
      final topic = await db.insertTopic('Test');
      final entry = await db.insertEntry(topicId: topic.id!, content: '');

      await db.insertEntryAttachment(
        entryId: entry.id!,
        filePath: '/a.jpg',
      );

      final attachments = await db.getEntryAttachments(entry.id!);

      expect(attachments.length, 1);
      expect(attachments.first.filePath, '/a.jpg');
    });

    test('getEntriesWithAttachments joins entries and attachments', () async {
      final topic = await db.insertTopic('Test');
      final entry =
          await db.insertEntry(topicId: topic.id!, content: 'Photo entry');
      await db.insertEntryAttachment(
        entryId: entry.id!,
        filePath: '/pic.jpg',
        mediaType: 'image',
      );

      final results = await db.getEntriesWithAttachments(topic.id!);

      expect(results.length, 1);
      expect(results.first.entry.content, 'Photo entry');
      expect(results.first.firstAttachment, isNotNull);
      expect(results.first.firstAttachment!.filePath, '/pic.jpg');
    });

    test('deleteEntryAttachments removes all attachments for entry', () async {
      final topic = await db.insertTopic('Test');
      final entry = await db.insertEntry(topicId: topic.id!, content: '');
      await db.insertEntryAttachment(
        entryId: entry.id!,
        filePath: '/a.jpg',
      );

      await db.deleteEntryAttachments(entry.id!);

      final attachments = await db.getEntryAttachments(entry.id!);
      expect(attachments, isEmpty);
    });

    test('deleteEntry cascades to attachments', () async {
      final topic = await db.insertTopic('Test');
      final entry = await db.insertEntry(topicId: topic.id!, content: '');
      await db.insertEntryAttachment(
        entryId: entry.id!,
        filePath: '/a.jpg',
      );

      await db.deleteEntry(entry.id!);

      final attachments = await db.getEntryAttachments(entry.id!);
      expect(attachments, isEmpty);
    });
  });

  // =========================================================================
  // FTS5 Search
  // =========================================================================

  group('Full-text search', () {
    test('searchEntries finds entries by content', () async {
      final topic = await db.insertTopic('Test');
      await db.insertEntry(topicId: topic.id!, content: 'Flutter is great');
      await db.insertEntry(topicId: topic.id!, content: 'Dart language');

      final results = await db.searchEntries('Flutter');

      expect(results.length, 1);
      expect(results.first.content, 'Flutter is great');
      expect(results.first.topicTitle, 'Test');
    });

    test('searchEntries supports prefix matching', () async {
      final topic = await db.insertTopic('Test');
      await db.insertEntry(topicId: topic.id!, content: 'Programming in Dart');

      final results = await db.searchEntries('Prog');

      expect(results.length, 1);
    });

    test('searchEntries returns empty for no matches', () async {
      final topic = await db.insertTopic('Test');
      await db.insertEntry(topicId: topic.id!, content: 'Hello world');

      final results = await db.searchEntries('xyz');

      expect(results, isEmpty);
    });

    test('searchEntries returns empty for empty query', () async {
      final results = await db.searchEntries('');

      expect(results, isEmpty);
    });

    test('FTS index updates when entry is updated', () async {
      final topic = await db.insertTopic('Test');
      final entry = await db.insertEntry(
          topicId: topic.id!, content: 'Old content');

      // Should find by old content.
      expect((await db.searchEntries('Old')).length, 1);

      // Update entry.
      await db.updateEntry(entry.copyWith(content: 'New content'));

      // Old content gone, new content searchable.
      expect((await db.searchEntries('Old')), isEmpty);
      expect((await db.searchEntries('New')).length, 1);
    });

    test('FTS index cleans up when entry is deleted', () async {
      final topic = await db.insertTopic('Test');
      final entry = await db.insertEntry(
          topicId: topic.id!, content: 'Searchable text');

      expect((await db.searchEntries('Searchable')).length, 1);

      await db.deleteEntry(entry.id!);

      expect((await db.searchEntries('Searchable')), isEmpty);
    });
  });

  // =========================================================================
  // Link Previews
  // =========================================================================

  group('Link Previews', () {
    test('insertLinkPreview and getLinkPreview roundtrip', () async {
      await db.insertLinkPreview(
        url: 'https://example.com',
        title: 'Example',
        description: 'A test site',
        siteName: 'Example.com',
      );

      final preview = await db.getLinkPreview('https://example.com');

      expect(preview, isNotNull);
      expect(preview!.title, 'Example');
      expect(preview.description, 'A test site');
      expect(preview.siteName, 'Example.com');
    });

    test('getLinkPreview returns null for unknown URL', () async {
      final preview = await db.getLinkPreview('https://unknown.com');

      expect(preview, isNull);
    });

    test('insertLinkPreview replaces on duplicate URL', () async {
      await db.insertLinkPreview(
        url: 'https://example.com',
        title: 'Old',
      );
      await db.insertLinkPreview(
        url: 'https://example.com',
        title: 'New',
      );

      final preview = await db.getLinkPreview('https://example.com');

      expect(preview!.title, 'New');
    });

    test('deleteLinkPreview removes preview', () async {
      await db.insertLinkPreview(
        url: 'https://example.com',
        title: 'Gone',
      );

      await db.deleteLinkPreview('https://example.com');

      final preview = await db.getLinkPreview('https://example.com');
      expect(preview, isNull);
    });
  });
}
