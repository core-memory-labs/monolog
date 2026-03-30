import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:monolog/models/entry.dart';
import 'package:monolog/models/entry_attachment.dart';
import 'package:monolog/models/entry_with_attachment.dart';
import 'package:monolog/models/topic.dart';
import 'package:monolog/services/export_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../helpers/test_helpers.dart';
import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockDatabaseService mockDb;
  late ExportService exportService;
  late Directory tempDir;

  final now = DateTime(2024, 3, 15, 10, 30);

  setUp(() {
    mockDb = MockDatabaseService();
    exportService = ExportService(db: mockDb);
    tempDir = createTestTempDir();
    PathProviderPlatform.instance = FakePathProvider(docsPath: tempDir.path);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  // =========================================================================
  // Helpers
  // =========================================================================

  /// Reads and parses data.json from an exported ZIP file.
  Map<String, dynamic> readExportedJson(String zipPath) {
    final zipBytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final dataJsonFile = archive.findFile('data.json')!;
    return json.decode(utf8.decode(dataJsonFile.content as List<int>))
        as Map<String, dynamic>;
  }

  // =========================================================================
  // Tests
  // =========================================================================

  group('Empty database', () {
    test('exports valid ZIP with empty topics array', () async {
      when(mockDb.getTopics()).thenAnswer((_) async => []);

      final result = await exportService.export();

      expect(result.topicCount, 0);
      expect(result.entryCount, 0);
      expect(result.fileCount, 0);
      expect(File(result.zipPath).existsSync(), isTrue);

      final data = readExportedJson(result.zipPath);
      expect(data['version'], 1);
      expect(data['app'], 'Monolog');
      expect(data['topics'], isEmpty);
      expect(data['exported_at'], isNotNull);

      // Clean up.
      File(result.zipPath).deleteSync();
    });
  });

  group('Export with data', () {
    test('exports topics with entries', () async {
      final topics = [
        Topic(
          id: 1,
          title: 'Work',
          isPinned: true,
          createdAt: now,
          updatedAt: now,
        ),
        Topic(id: 2, title: 'Personal', createdAt: now, updatedAt: now),
      ];

      when(mockDb.getTopics()).thenAnswer((_) async => topics);

      when(mockDb.getEntriesWithAttachments(1)).thenAnswer(
        (_) async => [
          EntryWithAttachment(
            entry: Entry(
              id: 10,
              topicId: 1,
              content: 'Task A',
              createdAt: now,
              updatedAt: now,
            ),
          ),
        ],
      );

      when(mockDb.getEntriesWithAttachments(2)).thenAnswer(
        (_) async => [
          EntryWithAttachment(
            entry: Entry(
              id: 20,
              topicId: 2,
              content: 'Note *bold*',
              createdAt: now,
              updatedAt: now,
            ),
          ),
        ],
      );

      final result = await exportService.export();

      expect(result.topicCount, 2);
      expect(result.entryCount, 2);

      final data = readExportedJson(result.zipPath);
      final exportedTopics = data['topics'] as List;
      expect(exportedTopics.length, 2);

      final workTopic = exportedTopics[0] as Map<String, dynamic>;
      expect(workTopic['title'], 'Work');
      expect(workTopic['is_pinned'], true);

      final workEntries = workTopic['entries'] as List;
      expect(workEntries.length, 1);
      expect(workEntries[0]['content'], 'Task A');

      // Clean up.
      File(result.zipPath).deleteSync();
    });

    test(
      'exports entries with attachments and includes files in ZIP',
      () async {
        // Create a real temp file to simulate an attachment on disk.
        final attachmentFile = File(p.join(tempDir.path, 'photo.jpg'));
        await attachmentFile.writeAsBytes(fakePngBytes(100));

        final topics = [
          Topic(id: 1, title: 'Photos', createdAt: now, updatedAt: now),
        ];

        when(mockDb.getTopics()).thenAnswer((_) async => topics);
        when(mockDb.getEntriesWithAttachments(1)).thenAnswer(
          (_) async => [
            EntryWithAttachment(
              entry: Entry(
                id: 10,
                topicId: 1,
                content: 'Nice view',
                createdAt: now,
                updatedAt: now,
              ),
              attachments: [
                EntryAttachment(
                  id: 1,
                  entryId: 10,
                  filePath: attachmentFile.path,
                  mediaType: 'image',
                  createdAt: now,
                  fileName: 'photo.jpg',
                  fileSize: 100,
                  mimeType: 'image/jpeg',
                ),
              ],
            ),
          ],
        );

        final result = await exportService.export();

        expect(result.topicCount, 1);
        expect(result.entryCount, 1);
        expect(result.fileCount, 1);

        // Verify JSON has attachment metadata.
        final data = readExportedJson(result.zipPath);
        final entry =
            (data['topics'] as List)[0]['entries'][0] as Map<String, dynamic>;
        expect(entry['attachment'], isNotNull);
        expect(entry['attachment']['file_name'], 'photo.jpg');
        expect(entry['attachment']['file'], 'files/photo.jpg');

        // Verify actual file is in the ZIP.
        final zipBytes = File(result.zipPath).readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(zipBytes);
        final photoFile = archive.findFile('files/photo.jpg');
        expect(photoFile, isNotNull);
        expect(photoFile!.content.length, 100);

        // Clean up.
        File(result.zipPath).deleteSync();
      },
    );

    test('handles missing attachment file gracefully', () async {
      final topics = [
        Topic(id: 1, title: 'Test', createdAt: now, updatedAt: now),
      ];

      when(mockDb.getTopics()).thenAnswer((_) async => topics);
      when(mockDb.getEntriesWithAttachments(1)).thenAnswer(
        (_) async => [
          EntryWithAttachment(
            entry: Entry(
              id: 10,
              topicId: 1,
              content: 'Entry with deleted file',
              createdAt: now,
              updatedAt: now,
            ),
            attachments: [
              EntryAttachment(
                id: 1,
                entryId: 10,
                filePath: '/nonexistent/path/photo.jpg',
                mediaType: 'image',
                createdAt: now,
                fileName: 'photo.jpg',
                fileSize: 1000,
                mimeType: 'image/jpeg',
              ),
            ],
          ),
        ],
      );

      final result = await exportService.export();

      // Export succeeds, file is not included.
      expect(result.entryCount, 1);
      expect(result.fileCount, 0);

      // JSON still has attachment metadata (without file path).
      final data = readExportedJson(result.zipPath);
      final entry =
          (data['topics'] as List)[0]['entries'][0] as Map<String, dynamic>;
      expect(entry['attachment'], isNotNull);
      expect(entry['attachment']['file_name'], 'photo.jpg');
      expect(entry['attachment'].containsKey('file'), isFalse);

      // Clean up.
      File(result.zipPath).deleteSync();
    });
  });

  group('JSON structure', () {
    test('version is 1 and app is Monolog', () async {
      when(mockDb.getTopics()).thenAnswer((_) async => []);

      final result = await exportService.export();
      final data = readExportedJson(result.zipPath);

      expect(data['version'], 1);
      expect(data['app'], 'Monolog');
      expect(data['exported_at'], isA<String>());

      File(result.zipPath).deleteSync();
    });

    test('entry dates are ISO 8601', () async {
      final created = DateTime(2024, 6, 15, 9, 30, 45);
      final updated = DateTime(2024, 6, 15, 10, 0, 0);

      when(mockDb.getTopics()).thenAnswer(
        (_) async => [Topic(id: 1, title: 'T', createdAt: now, updatedAt: now)],
      );
      when(mockDb.getEntriesWithAttachments(1)).thenAnswer(
        (_) async => [
          EntryWithAttachment(
            entry: Entry(
              id: 1,
              topicId: 1,
              content: 'Test',
              createdAt: created,
              updatedAt: updated,
            ),
          ),
        ],
      );

      final result = await exportService.export();
      final data = readExportedJson(result.zipPath);
      final entry =
          (data['topics'] as List)[0]['entries'][0] as Map<String, dynamic>;

      // Verify dates can be parsed back.
      expect(
        () => DateTime.parse(entry['created_at'] as String),
        returnsNormally,
      );
      expect(
        () => DateTime.parse(entry['updated_at'] as String),
        returnsNormally,
      );

      File(result.zipPath).deleteSync();
    });
  });
}
