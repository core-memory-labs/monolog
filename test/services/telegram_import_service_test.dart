import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:monolog/models/entry.dart';
import 'package:monolog/models/entry_attachment.dart';
import 'package:monolog/models/topic.dart';
import 'package:monolog/services/telegram_import_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../helpers/test_helpers.dart';
import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockDatabaseService mockDb;
  late MockFileService mockFileService;
  late TelegramImportService importService;
  late Directory tempDir;

  final now = DateTime(2024, 1, 15, 12, 0);

  setUp(() {
    mockDb = MockDatabaseService();
    mockFileService = MockFileService();
    importService = TelegramImportService(
      db: mockDb,
      fileService: mockFileService,
    );
    tempDir = createTestTempDir();
    PathProviderPlatform.instance = FakePathProvider(docsPath: tempDir.path);
    // Default stubs.
    _stubDefaults(mockDb, mockFileService);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  // =========================================================================
  // Basic import
  // =========================================================================

  group('Basic import', () {
    test('imports topics and text messages', () async {
      final data = telegramExport(
        messages: [
          topicCreatedMsg(1, 'Work'),
          topicCreatedMsg(2, 'Personal'),
          textMsg(10, 1, 'Task A'),
          textMsg(11, 2, 'Note B'),
          textMsg(12, 1, 'Task C'),
        ],
      );
      final zipPath = p.join(tempDir.path, 'test.zip');
      await createTestZip(data, zipPath: zipPath);

      final result = await importService.importFromZip(zipPath);

      expect(result.topicCount, 2);
      expect(result.entryCount, 3);
      expect(result.fileCount, 0);
      expect(result.skippedCount, 0);

      // Verify topics were created.
      verify(mockDb.insertTopic('Work')).called(1);
      verify(mockDb.insertTopic('Personal')).called(1);

      // Verify entries were created with correct content.
      verify(
        mockDb.insertEntry(
          topicId: 1,
          content: 'Task A',
          createdAt: anyNamed('createdAt'),
        ),
      ).called(1);
      verify(
        mockDb.insertEntry(
          topicId: 2,
          content: 'Note B',
          createdAt: anyNamed('createdAt'),
        ),
      ).called(1);
    });

    test('preserves original Telegram dates', () async {
      final data = telegramExport(
        messages: [
          topicCreatedMsg(1, 'Test'),
          textMsg(10, 1, 'Hello', date: '2023-06-15T09:30:00'),
        ],
      );
      final zipPath = p.join(tempDir.path, 'test.zip');
      await createTestZip(data, zipPath: zipPath);

      await importService.importFromZip(zipPath);

      final captured = verify(
        mockDb.insertEntry(
          topicId: anyNamed('topicId'),
          content: anyNamed('content'),
          createdAt: captureAnyNamed('createdAt'),
        ),
      ).captured;

      final createdAt = captured.first as DateTime;
      expect(createdAt, DateTime(2023, 6, 15, 9, 30));
    });

    test('messages without topic go to General (group name)', () async {
      // No topic_created messages — all go to General.
      final data = telegramExport(
        name: 'My Notes',
        messages: [textMsg(10, 999, 'Orphan message')],
      );
      final zipPath = p.join(tempDir.path, 'test.zip');
      await createTestZip(data, zipPath: zipPath);

      final result = await importService.importFromZip(zipPath);

      expect(result.topicCount, 1);
      verify(mockDb.insertTopic('My Notes')).called(1);
    });

    test('skips messages with no content and no attachment', () async {
      final data = telegramExport(
        messages: [
          topicCreatedMsg(1, 'Test'),
          textMsg(10, 1, ''), // empty text, no attachment
        ],
      );
      final zipPath = p.join(tempDir.path, 'test.zip');
      await createTestZip(data, zipPath: zipPath);

      final result = await importService.importFromZip(zipPath);

      expect(result.entryCount, 0);
      expect(result.skippedCount, 1);
      verifyNever(
        mockDb.insertEntry(
          topicId: anyNamed('topicId'),
          content: anyNamed('content'),
          createdAt: anyNamed('createdAt'),
        ),
      );
    });
  });

  // =========================================================================
  // Reply chain resolution
  // =========================================================================

  group('Reply chain resolution', () {
    test('resolves reply-to-message chains to correct topic', () async {
      // msg 10 → topic 1 (direct)
      // msg 11 → msg 10 → topic 1 (one hop)
      // msg 12 → msg 11 → msg 10 → topic 1 (two hops)
      final data = telegramExport(
        messages: [
          topicCreatedMsg(1, 'Work'),
          textMsg(10, 1, 'Direct to topic'),
          textMsg(11, 10, 'Reply to msg 10'),
          textMsg(12, 11, 'Reply to msg 11'),
        ],
      );
      final zipPath = p.join(tempDir.path, 'test.zip');
      await createTestZip(data, zipPath: zipPath);

      final result = await importService.importFromZip(zipPath);

      expect(result.entryCount, 3);
      // All three should go to topic "Work" (id=1).
      verify(
        mockDb.insertEntry(
          topicId: 1,
          content: 'Direct to topic',
          createdAt: anyNamed('createdAt'),
        ),
      ).called(1);
      verify(
        mockDb.insertEntry(
          topicId: 1,
          content: 'Reply to msg 10',
          createdAt: anyNamed('createdAt'),
        ),
      ).called(1);
      verify(
        mockDb.insertEntry(
          topicId: 1,
          content: 'Reply to msg 11',
          createdAt: anyNamed('createdAt'),
        ),
      ).called(1);
    });

    test('unresolvable reply chain falls back to General', () async {
      // msg 20 → msg 19 (which doesn't exist) → can't resolve → General
      final data = telegramExport(
        name: 'TestGroup',
        messages: [
          topicCreatedMsg(1, 'Work'),
          {
            'id': 20,
            'type': 'message',
            'date': '2024-01-15T12:00:00',
            'date_unixtime': '1705320000',
            'from': 'Test User',
            'from_id': 'user123',
            'reply_to_message_id': 19, // msg 19 doesn't exist
            'text': 'Lost message',
            'text_entities': [],
          },
        ],
      );
      final zipPath = p.join(tempDir.path, 'test.zip');
      await createTestZip(data, zipPath: zipPath);

      final result = await importService.importFromZip(zipPath);

      expect(result.topicCount, 2); // "Work" + "TestGroup" (General)
      verify(mockDb.insertTopic('TestGroup')).called(1);
    });
  });

  // =========================================================================
  // Text formatting / segment conversion
  // =========================================================================

  group('Text segment conversion', () {
    test(
      'converts text array with bold, italic, code, strikethrough',
      () async {
        final data = telegramExport(
          messages: [
            topicCreatedMsg(1, 'Test'),
            textMsg(10, 1, [
              'Hello ',
              {'type': 'bold', 'text': 'world'},
              ' and ',
              {'type': 'italic', 'text': 'italic'},
              ' with ',
              {'type': 'code', 'text': 'code()'},
              ' and ',
              {'type': 'strikethrough', 'text': 'deleted'},
            ]),
          ],
        );
        final zipPath = p.join(tempDir.path, 'test.zip');
        await createTestZip(data, zipPath: zipPath);

        await importService.importFromZip(zipPath);

        verify(
          mockDb.insertEntry(
            topicId: anyNamed('topicId'),
            content: 'Hello *world* and _italic_ with `code()` and ~deleted~',
            createdAt: anyNamed('createdAt'),
          ),
        ).called(1);
      },
    );

    test('converts pre (code block) segments', () async {
      final data = telegramExport(
        messages: [
          topicCreatedMsg(1, 'Test'),
          textMsg(10, 1, [
            {'type': 'pre', 'text': 'print("hi")'},
          ]),
        ],
      );
      final zipPath = p.join(tempDir.path, 'test.zip');
      await createTestZip(data, zipPath: zipPath);

      await importService.importFromZip(zipPath);

      verify(
        mockDb.insertEntry(
          topicId: anyNamed('topicId'),
          content: '```\nprint("hi")\n```',
          createdAt: anyNamed('createdAt'),
        ),
      ).called(1);
    });

    test('converts blockquote segments to > syntax', () async {
      final data = telegramExport(
        messages: [
          topicCreatedMsg(1, 'Test'),
          textMsg(10, 1, [
            {'type': 'blockquote', 'text': 'Line one\nLine two'},
          ]),
        ],
      );
      final zipPath = p.join(tempDir.path, 'test.zip');
      await createTestZip(data, zipPath: zipPath);

      await importService.importFromZip(zipPath);

      verify(
        mockDb.insertEntry(
          topicId: anyNamed('topicId'),
          content: '> Line one\n> Line two',
          createdAt: anyNamed('createdAt'),
        ),
      ).called(1);
    });

    test('converts text_link to text + URL', () async {
      final data = telegramExport(
        messages: [
          topicCreatedMsg(1, 'Test'),
          textMsg(10, 1, [
            'Check ',
            {
              'type': 'text_link',
              'text': 'this article',
              'href': 'https://example.com/article',
            },
          ]),
        ],
      );
      final zipPath = p.join(tempDir.path, 'test.zip');
      await createTestZip(data, zipPath: zipPath);

      await importService.importFromZip(zipPath);

      verify(
        mockDb.insertEntry(
          topicId: anyNamed('topicId'),
          content: 'Check this article\nhttps://example.com/article',
          createdAt: anyNamed('createdAt'),
        ),
      ).called(1);
    });

    test(
      'passes through hashtag, email, phone, mention as plain text',
      () async {
        final data = telegramExport(
          messages: [
            topicCreatedMsg(1, 'Test'),
            textMsg(10, 1, [
              {'type': 'hashtag', 'text': '#dev'},
              ' ',
              {'type': 'email', 'text': 'test@example.com'},
              ' ',
              {'type': 'phone', 'text': '1234567890'},
              ' ',
              {'type': 'mention', 'text': '@username'},
            ]),
          ],
        );
        final zipPath = p.join(tempDir.path, 'test.zip');
        await createTestZip(data, zipPath: zipPath);

        await importService.importFromZip(zipPath);

        verify(
          mockDb.insertEntry(
            topicId: anyNamed('topicId'),
            content: '#dev test@example.com 1234567890 @username',
            createdAt: anyNamed('createdAt'),
          ),
        ).called(1);
      },
    );

    test('handles plain string text (not array)', () async {
      final data = telegramExport(
        messages: [
          topicCreatedMsg(1, 'Test'),
          textMsg(10, 1, 'Simple plain string'),
        ],
      );
      final zipPath = p.join(tempDir.path, 'test.zip');
      await createTestZip(data, zipPath: zipPath);

      await importService.importFromZip(zipPath);

      verify(
        mockDb.insertEntry(
          topicId: anyNamed('topicId'),
          content: 'Simple plain string',
          createdAt: anyNamed('createdAt'),
        ),
      ).called(1);
    });
  });

  // =========================================================================
  // Attachments
  // =========================================================================

  group('Attachments', () {
    test('imports photo messages', () async {
      final imageBytes = fakePngBytes();
      final data = telegramExport(
        messages: [
          topicCreatedMsg(1, 'Photos'),
          photoMsg(10, 1, text: 'Nice view', photo: 'photos/pic.jpg'),
        ],
      );
      final zipPath = p.join(tempDir.path, 'test.zip');
      await createTestZip(
        data,
        zipPath: zipPath,
        files: {'photos/pic.jpg': imageBytes},
      );

      final result = await importService.importFromZip(zipPath);

      expect(result.entryCount, 1);
      expect(result.fileCount, 1);

      verify(
        mockFileService.saveFile(
          argThat(endsWith('pic.jpg')),
          fileName: 'pic.jpg',
        ),
      ).called(1);

      verify(
        mockDb.insertEntryAttachment(
          entryId: anyNamed('entryId'),
          filePath: '/mock/saved/path',
          mediaType: 'image',
          fileName: 'pic.jpg',
          fileSize: 12345,
          mimeType: anyNamed('mimeType'),
        ),
      ).called(1);
    });

    test('imports file messages (PDF)', () async {
      final pdfBytes = fakePdfBytes();
      final data = telegramExport(
        messages: [
          topicCreatedMsg(1, 'Docs'),
          fileMsg(10, 1, file: 'files/report.pdf', fileName: 'report.pdf'),
        ],
      );
      final zipPath = p.join(tempDir.path, 'test.zip');
      await createTestZip(
        data,
        zipPath: zipPath,
        files: {'files/report.pdf': pdfBytes},
      );

      final result = await importService.importFromZip(zipPath);

      expect(result.fileCount, 1);

      verify(
        mockDb.insertEntryAttachment(
          entryId: anyNamed('entryId'),
          filePath: '/mock/saved/path',
          mediaType: 'file',
          fileName: 'report.pdf',
          fileSize: 54321,
          mimeType: 'application/pdf',
        ),
      ).called(1);
    });

    test('skips attachment when file is missing from archive', () async {
      final data = telegramExport(
        messages: [
          topicCreatedMsg(1, 'Test'),
          photoMsg(10, 1, photo: 'photos/missing.jpg'),
        ],
      );
      // Note: no files added to ZIP.
      final zipPath = p.join(tempDir.path, 'test.zip');
      await createTestZip(data, zipPath: zipPath);

      final result = await importService.importFromZip(zipPath);

      // Entry is still created (with empty text), but no attachment.
      expect(result.entryCount, 1); // entry created because attachmentInfo existed; only file save was skipped
      expect(result.fileCount, 0);
    });

    test('voice messages without file_name use basename from path', () async {
      final oggBytes = List.generate(32, (i) => i);
      final data = telegramExport(
        messages: [
          topicCreatedMsg(1, 'Voice'),
          {
            ...textMsg(10, 1, ''),
            'file': 'voice_messages/audio_1.ogg',
            'mime_type': 'audio/ogg',
            'media_type': 'voice_message',
            'file_size': 32,
            // No file_name — voice messages typically lack it.
          },
        ],
      );
      final zipPath = p.join(tempDir.path, 'test.zip');
      await createTestZip(
        data,
        zipPath: zipPath,
        files: {'voice_messages/audio_1.ogg': oggBytes},
      );

      final result = await importService.importFromZip(zipPath);

      expect(result.fileCount, 1);
      verify(
        mockFileService.saveFile(
          argThat(endsWith('audio_1.ogg')),
          fileName: 'audio_1.ogg',
        ),
      ).called(1);
    });
  });

  // =========================================================================
  // Error handling
  // =========================================================================

  group('Error handling', () {
    test('throws FormatException when result.json is missing', () async {
      // Create ZIP without result.json.
      final archive = Archive();
      archive.addFile(ArchiveFile('readme.txt', 5, [0, 1, 2, 3, 4]));
      final zipBytes = ZipEncoder().encode(archive)!;
      final zipPath = p.join(tempDir.path, 'bad.zip');
      await File(zipPath).writeAsBytes(zipBytes);

      expect(
        () => importService.importFromZip(zipPath),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('result.json не найден'),
          ),
        ),
      );
    });

    test('throws FormatException for invalid JSON', () async {
      final archive = Archive();
      final badJson = [0x7B, 0x7B, 0x7B]; // "{{{" — invalid JSON
      archive.addFile(ArchiveFile('result.json', badJson.length, badJson));
      final zipBytes = ZipEncoder().encode(archive)!;
      final zipPath = p.join(tempDir.path, 'bad.zip');
      await File(zipPath).writeAsBytes(zipBytes);

      expect(
        () => importService.importFromZip(zipPath),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Невалидный JSON'),
          ),
        ),
      );
    });

    test('throws FormatException for empty messages array', () async {
      final data = telegramExport(messages: []);
      final zipPath = p.join(tempDir.path, 'test.zip');
      await createTestZip(data, zipPath: zipPath);

      expect(
        () => importService.importFromZip(zipPath),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('не содержит сообщений'),
          ),
        ),
      );
    });
  });

  // =========================================================================
  // ZIP structure variants
  // =========================================================================

  group('ZIP structure', () {
    test('handles nested directory (archive from parent folder)', () async {
      final data = telegramExport(
        messages: [
          topicCreatedMsg(1, 'Test'),
          textMsg(10, 1, 'Hello from nested'),
        ],
      );
      final zipPath = p.join(tempDir.path, 'test.zip');
      await createTestZip(data, zipPath: zipPath, nestedDir: 'ChatExport');

      final result = await importService.importFromZip(zipPath);

      expect(result.topicCount, 1);
      expect(result.entryCount, 1);
    });

    test(
      'resolves media paths relative to result.json in nested dir',
      () async {
        final imageBytes = fakePngBytes();
        final data = telegramExport(
          messages: [
            topicCreatedMsg(1, 'Test'),
            photoMsg(10, 1, photo: 'photos/pic.jpg'),
          ],
        );
        final zipPath = p.join(tempDir.path, 'test.zip');
        await createTestZip(
          data,
          zipPath: zipPath,
          nestedDir: 'Export',
          files: {'photos/pic.jpg': imageBytes},
        );

        final result = await importService.importFromZip(zipPath);

        expect(result.fileCount, 1);
      },
    );
  });

  // =========================================================================
  // Topic deduplication
  // =========================================================================

  group('Topic deduplication', () {
    test('appends suffix when topic name already exists', () async {
      // Simulate existing topic with same name.
      when(mockDb.getTopics()).thenAnswer(
        (_) async => [
          Topic(id: 100, title: 'Work', createdAt: now, updatedAt: now),
        ],
      );

      final data = telegramExport(
        messages: [topicCreatedMsg(1, 'Work'), textMsg(10, 1, 'Task')],
      );
      final zipPath = p.join(tempDir.path, 'test.zip');
      await createTestZip(data, zipPath: zipPath);

      await importService.importFromZip(zipPath);

      // Should create "Work (2)" instead of "Work".
      verify(mockDb.insertTopic('Work (2)')).called(1);
    });
  });
}

// =============================================================================
// Mock stubs
// =============================================================================

/// Sets up default return values for all mocked methods.
void _stubDefaults(MockDatabaseService mockDb, MockFileService mockFs) {
  var topicId = 1;
  var entryId = 1;
  var attachmentId = 1;

  // DatabaseService stubs.
  when(mockDb.getTopics()).thenAnswer((_) async => []);

  when(mockDb.insertTopic(any)).thenAnswer((inv) async {
    final title = inv.positionalArguments[0] as String;
    final id = topicId++;
    return Topic(
      id: id,
      title: title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  });

  when(
    mockDb.insertEntry(
      topicId: anyNamed('topicId'),
      content: anyNamed('content'),
      createdAt: anyNamed('createdAt'),
    ),
  ).thenAnswer((inv) async {
    final id = entryId++;
    return Entry(
      id: id,
      topicId: inv.namedArguments[#topicId] as int,
      content: inv.namedArguments[#content] as String,
      createdAt: inv.namedArguments[#createdAt] as DateTime? ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  });

  when(
    mockDb.insertEntryAttachment(
      entryId: anyNamed('entryId'),
      filePath: anyNamed('filePath'),
      mediaType: anyNamed('mediaType'),
      fileName: anyNamed('fileName'),
      fileSize: anyNamed('fileSize'),
      mimeType: anyNamed('mimeType'),
    ),
  ).thenAnswer((inv) async {
    final id = attachmentId++;
    return EntryAttachment(
      id: id,
      entryId: inv.namedArguments[#entryId] as int,
      filePath: inv.namedArguments[#filePath] as String,
      mediaType: inv.namedArguments[#mediaType] as String? ?? 'image',
      createdAt: DateTime.now(),
      fileName: inv.namedArguments[#fileName] as String?,
      fileSize: inv.namedArguments[#fileSize] as int?,
      mimeType: inv.namedArguments[#mimeType] as String?,
    );
  });

  // FileService stubs.
  when(
    mockFs.saveFile(any, fileName: anyNamed('fileName')),
  ).thenAnswer((_) async => '/mock/saved/path');
}
