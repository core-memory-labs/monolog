import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/database_service.dart';

/// Result of an export operation.
class ExportResult {
  final String zipPath;
  final int topicCount;
  final int entryCount;
  final int fileCount;

  const ExportResult({
    required this.zipPath,
    required this.topicCount,
    required this.entryCount,
    required this.fileCount,
  });
}

/// Exports all Monolog data (topics, entries, attachments) into a ZIP archive.
///
/// The archive contains:
/// - `data.json` — structured export of all topics and entries.
/// - `files/` — all attachment files referenced by entries.
class ExportService {
  final DatabaseService _db;

  ExportService({required DatabaseService db}) : _db = db;

  /// Creates a ZIP backup in the system temp directory and returns
  /// the path to the archive along with statistics.
  Future<ExportResult> export() async {
    final archive = Archive();

    var topicCount = 0;
    var entryCount = 0;
    var fileCount = 0;

    // Fetch all topics.
    final topics = await _db.getTopics();
    final topicsJson = <Map<String, dynamic>>[];

    for (final topic in topics) {
      topicCount++;
      final entries = await _db.getEntriesWithAttachments(topic.id!);
      final entriesJson = <Map<String, dynamic>>[];

      for (final ewa in entries) {
        entryCount++;
        final entry = ewa.entry;
        Map<String, dynamic>? attachmentJson;

        final att = ewa.firstAttachment;
        if (att != null) {
          // Try to read the file from disk.
          final file = File(att.filePath);
          String? relativePath;

          if (await file.exists()) {
            final fileName = p.basename(att.filePath);
            relativePath = 'files/$fileName';

            try {
              final bytes = await file.readAsBytes();
              archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
              fileCount++;
            } catch (e) {
              // File unreadable — skip it, still record metadata.
              relativePath = null;
            }
          }

          attachmentJson = {
            'file_name': att.fileName,
            'media_type': att.mediaType,
            'mime_type': att.mimeType,
            'file_size': att.fileSize,
            if (relativePath != null) 'file': relativePath,
          };
        }

        entriesJson.add({
          'content': entry.content,
          'created_at': entry.createdAt.toIso8601String(),
          'updated_at': entry.updatedAt.toIso8601String(),
          if (attachmentJson != null) 'attachment': attachmentJson,
        });
      }

      topicsJson.add({
        'title': topic.title,
        'is_pinned': topic.isPinned,
        'created_at': topic.createdAt.toIso8601String(),
        'updated_at': topic.updatedAt.toIso8601String(),
        'entries': entriesJson,
      });
    }

    final dataJson = {
      'version': 1,
      'app': 'Monolog',
      'exported_at': DateTime.now().toIso8601String(),
      'topics': topicsJson,
    };

    // Add data.json to archive.
    final jsonBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(dataJson),
    );
    archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

    // Encode ZIP and write to temp directory.
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw Exception('Failed to encode ZIP archive');
    }

    final tempDir = await getTemporaryDirectory();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final zipPath = p.join(tempDir.path, 'monolog_backup_$date.zip');
    await File(zipPath).writeAsBytes(zipBytes);

    return ExportResult(
      zipPath: zipPath,
      topicCount: topicCount,
      entryCount: entryCount,
      fileCount: fileCount,
    );
  }
}
