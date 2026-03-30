import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Fake PathProviderPlatform that redirects all paths to [docsPath].
class FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String docsPath;

  FakePathProvider({required this.docsPath});

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;

  @override
  Future<String?> getTemporaryPath() async => docsPath;

  @override
  Future<String?> getApplicationSupportPath() async => docsPath;

  @override
  Future<String?> getApplicationCachePath() async => docsPath;

  @override
  Future<String?> getExternalStoragePath() async => docsPath;

  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) async => [docsPath];

  @override
  Future<List<String>?> getExternalCachePaths() async => [docsPath];

  @override
  Future<String?> getDownloadsPath() async => docsPath;
}

/// Creates a temporary directory for tests. Caller must clean up.
Directory createTestTempDir([String prefix = 'monolog_test_']) {
  return Directory.systemTemp.createTempSync(prefix);
}

// ---------------------------------------------------------------------------
// Telegram export data builders
// ---------------------------------------------------------------------------

/// Builds a minimal Telegram export JSON structure.
Map<String, dynamic> telegramExport({
  String name = 'TestGroup',
  List<Map<String, dynamic>> messages = const [],
}) {
  return {
    'name': name,
    'type': 'private_supergroup',
    'id': 12345,
    'messages': messages,
  };
}

/// A `topic_created` service message.
Map<String, dynamic> topicCreatedMsg(int id, String title) => {
      'id': id,
      'type': 'service',
      'date': '2024-01-01T00:00:00',
      'date_unixtime': '1704067200',
      'actor': 'Test User',
      'actor_id': 'user123',
      'action': 'topic_created',
      'title': title,
      'text': '',
      'text_entities': [],
    };

/// A regular text message belonging to a topic (via reply_to_message_id).
Map<String, dynamic> textMsg(
  int id,
  int replyTo,
  dynamic text, {
  String date = '2024-01-15T12:00:00',
}) =>
    {
      'id': id,
      'type': 'message',
      'date': date,
      'date_unixtime': '1705320000',
      'from': 'Test User',
      'from_id': 'user123',
      'reply_to_message_id': replyTo,
      'text': text,
      'text_entities': [],
    };

/// A message with a photo attachment.
Map<String, dynamic> photoMsg(
  int id,
  int replyTo, {
  String text = '',
  String photo = 'photos/photo_1.jpg',
  int photoFileSize = 12345,
}) =>
    {
      ...textMsg(id, replyTo, text),
      'photo': photo,
      'photo_file_size': photoFileSize,
    };

/// A message with a file attachment.
Map<String, dynamic> fileMsg(
  int id,
  int replyTo, {
  String text = '',
  String file = 'files/doc.pdf',
  String? fileName = 'doc.pdf',
  String mimeType = 'application/pdf',
  int fileSize = 54321,
}) =>
    {
      ...textMsg(id, replyTo, text),
      'file': file,
      if (fileName != null) 'file_name': fileName,
      'mime_type': mimeType,
      'file_size': fileSize,
    };

// ---------------------------------------------------------------------------
// ZIP creation helpers
// ---------------------------------------------------------------------------

/// Creates a ZIP file at [zipPath] containing `result.json` built from
/// [data], plus optional [files] (relative path → content bytes).
///
/// If [nestedDir] is provided, all files are placed inside that subdirectory
/// within the archive (simulates user zipping a parent directory).
Future<String> createTestZip(
  Map<String, dynamic> data, {
  Map<String, List<int>>? files,
  String? nestedDir,
  required String zipPath,
}) async {
  final archive = Archive();

  String archivePath(String name) =>
      nestedDir != null ? '$nestedDir/$name' : name;

  // Add result.json.
  final jsonBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
  archive.addFile(ArchiveFile(
    archivePath('result.json'),
    jsonBytes.length,
    jsonBytes,
  ));

  // Add extra files (photos, documents, etc.).
  if (files != null) {
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile(
        archivePath(entry.key),
        entry.value.length,
        entry.value,
      ));
    }
  }

  final zipBytes = ZipEncoder().encode(archive)!;
  await File(zipPath).writeAsBytes(zipBytes);
  return zipPath;
}

/// Creates a small PNG-like byte sequence for test image files.
List<int> fakePngBytes([int size = 64]) =>
    List.generate(size, (i) => i % 256);

/// Creates a small PDF-like byte sequence for test file attachments.
List<int> fakePdfBytes([int size = 128]) =>
    [...utf8.encode('%PDF-1.4 '), ...List.generate(size - 10, (i) => i % 256)];
