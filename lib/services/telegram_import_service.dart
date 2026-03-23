import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/database_service.dart';
import '../services/file_service.dart';
import '../utils/file_utils.dart';

/// Result of a Telegram import operation.
class TelegramImportResult {
  final int topicCount;
  final int entryCount;
  final int fileCount;
  final int skippedCount;

  const TelegramImportResult({
    required this.topicCount,
    required this.entryCount,
    required this.fileCount,
    required this.skippedCount,
  });
}

/// Imports data from a Telegram chat export (ZIP containing `result.json`
/// and media files) into Monolog.
///
/// Telegram export format:
/// - `result.json` — array of messages with service events and text messages.
/// - `photos/`, `files/`, `video_files/`, `voice_messages/` — media directories.
///
/// Topics are identified from service messages with `action: "topic_created"`.
/// Regular messages reference their topic via `reply_to_message_id`.
/// Messages without a topic reference go to a "General" topic (named after
/// the group).
class TelegramImportService {
  final DatabaseService _db;
  final FileService _fileService;

  TelegramImportService({
    required DatabaseService db,
    required FileService fileService,
  })  : _db = db,
        _fileService = fileService;

  /// Imports a Telegram export from [zipPath].
  ///
  /// Extracts the ZIP, parses `result.json`, creates topics and entries.
  /// Throws [FormatException] if the ZIP doesn't contain a valid export.
  Future<TelegramImportResult> importFromZip(String zipPath) async {
    // Extract ZIP to temp directory.
    final tempDir = await _extractZip(zipPath);

    try {
      // Find result.json — could be at root or inside a subfolder.
      final resultJsonFile = _findResultJson(tempDir);
      if (resultJsonFile == null) {
        throw const FormatException(
          'Файл result.json не найден в архиве',
        );
      }

      final jsonString = await resultJsonFile.readAsString();
      final Map<String, dynamic> data;
      try {
        data = json.decode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        throw const FormatException('Невалидный JSON в result.json');
      }

      // The base directory for resolving relative file paths.
      final baseDir = resultJsonFile.parent.path;

      return await _processExport(data, baseDir);
    } finally {
      // Clean up temp directory.
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // ZIP extraction
  // ---------------------------------------------------------------------------

  Future<Directory> _extractZip(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final tempDir = await getTemporaryDirectory();
    final extractDir = Directory(
      p.join(tempDir.path, 'telegram_import_${DateTime.now().millisecondsSinceEpoch}'),
    );
    await extractDir.create(recursive: true);

    for (final file in archive) {
      final outPath = p.join(extractDir.path, file.name);
      if (file.isFile) {
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }

    return extractDir;
  }

  /// Finds `result.json` — either directly in [dir] or one level deep
  /// (Telegram export may be wrapped in a subfolder).
  File? _findResultJson(Directory dir) {
    // Check root.
    final rootFile = File(p.join(dir.path, 'result.json'));
    if (rootFile.existsSync()) return rootFile;

    // Check one level of subdirectories.
    for (final entity in dir.listSync()) {
      if (entity is Directory) {
        final subFile = File(p.join(entity.path, 'result.json'));
        if (subFile.existsSync()) return subFile;
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Export processing
  // ---------------------------------------------------------------------------

  Future<TelegramImportResult> _processExport(
    Map<String, dynamic> data,
    String baseDir,
  ) async {
    final groupName = (data['name'] as String?) ?? 'General';
    final messages = data['messages'] as List<dynamic>? ?? [];

    // --- First pass: collect topic names from service messages ----------------
    // Map: telegram message_id → topic title.
    final topicTitleMap = <int, String>{};

    for (final msg in messages) {
      if (msg is! Map<String, dynamic>) continue;
      if (msg['type'] != 'service') continue;
      if (msg['action'] != 'topic_created') continue;

      final id = msg['id'];
      final title = msg['title'] as String?;
      if (id != null && title != null) {
        topicTitleMap[id is int ? id : int.tryParse(id.toString()) ?? 0] =
            title;
      }
    }

    // --- Create Monolog topics -----------------------------------------------
    // Fetch existing topic names for deduplication.
    final existingTopics = await _db.getTopics();
    final existingNames =
        existingTopics.map((t) => t.title.toLowerCase()).toSet();

    // Map: topic title → Monolog topic ID.
    final topicIdMap = <String, int>{};

    // Create topics from Telegram.
    for (final title in topicTitleMap.values) {
      if (topicIdMap.containsKey(title)) continue; // already created
      final uniqueTitle = _uniqueTitle(title, existingNames);
      final topic = await _db.insertTopic(uniqueTitle);
      topicIdMap[title] = topic.id!;
      existingNames.add(uniqueTitle.toLowerCase());
    }

    // "General" topic for messages without reply_to_message_id.
    // Created lazily — only if there are such messages.
    int? generalTopicId;

    // --- Second pass: process messages ---------------------------------------
    var entryCount = 0;
    var fileCount = 0;
    var skippedCount = 0;

    for (final msg in messages) {
      if (msg is! Map<String, dynamic>) continue;
      if (msg['type'] != 'message') continue;

      // Determine topic.
      final replyTo = msg['reply_to_message_id'];
      int? topicId;

      if (replyTo != null) {
        final replyToInt =
            replyTo is int ? replyTo : int.tryParse(replyTo.toString());
        if (replyToInt != null) {
          final topicTitle = topicTitleMap[replyToInt];
          if (topicTitle != null) {
            topicId = topicIdMap[topicTitle];
          }
        }
      }

      if (topicId == null) {
        // No topic found — use General.
        if (generalTopicId == null) {
          final uniqueTitle = _uniqueTitle(groupName, existingNames);
          final topic = await _db.insertTopic(uniqueTitle);
          generalTopicId = topic.id!;
          existingNames.add(uniqueTitle.toLowerCase());
        }
        topicId = generalTopicId;
      }

      // Convert text.
      final content = _convertText(msg);

      // Determine attachment.
      final attachmentInfo = _extractAttachment(msg, baseDir);

      // Skip messages with no content and no attachment.
      if (content.isEmpty && attachmentInfo == null) {
        skippedCount++;
        continue;
      }

      // Parse date.
      final dateStr = msg['date'] as String?;
      final date =
          dateStr != null ? DateTime.tryParse(dateStr) : null;
      final now = date ?? DateTime.now();

      // Create entry (with original Telegram date preserved).
      final entry = await _db.insertEntry(
        topicId: topicId,
        content: content,
        createdAt: now,
      );

      entryCount++;

      // Handle attachment.
      if (attachmentInfo != null && entry.id != null) {
        final savedPath = await _saveAttachmentFile(
          attachmentInfo.sourcePath,
          attachmentInfo.fileName,
        );
        if (savedPath != null) {
          await _db.insertEntryAttachment(
            entryId: entry.id!,
            filePath: savedPath,
            mediaType: attachmentInfo.mediaType,
            fileName: attachmentInfo.fileName,
            fileSize: attachmentInfo.fileSize,
            mimeType: attachmentInfo.mimeType,
          );
          fileCount++;
        }
      }
    }

    final topicCount =
        topicIdMap.length + (generalTopicId != null ? 1 : 0);

    return TelegramImportResult(
      topicCount: topicCount,
      entryCount: entryCount,
      fileCount: fileCount,
      skippedCount: skippedCount,
    );
  }

  // ---------------------------------------------------------------------------
  // Text conversion: Telegram text_entities → Monolog markdown
  // ---------------------------------------------------------------------------

  String _convertText(Map<String, dynamic> msg) {
    final text = msg['text'];

    if (text is String) return text;

    if (text is List) {
      final buffer = StringBuffer();
      for (final segment in text) {
        if (segment is String) {
          buffer.write(segment);
        } else if (segment is Map<String, dynamic>) {
          final type = segment['type'] as String? ?? 'plain';
          final value = segment['text'] as String? ?? '';
          buffer.write(_formatSegment(type, value, segment));
        }
      }
      return buffer.toString();
    }

    return '';
  }

  String _formatSegment(
    String type,
    String text,
    Map<String, dynamic> segment,
  ) {
    return switch (type) {
      'bold' => '*$text*',
      'italic' => '_${text}_',
      'strikethrough' => '~$text~',
      'code' => '`$text`',
      'pre' => '```\n$text\n```',
      'link' => text, // URL — detection handles it.
      'text_link' => _formatTextLink(text, segment),
      // underline, spoiler, mention, etc. — pass through as plain text.
      _ => text,
    };
  }

  String _formatTextLink(String text, Map<String, dynamic> segment) {
    final href = segment['href'] as String?;
    if (href == null || href == text) return text;
    // Display text followed by URL on next line for readability.
    return '$text\n$href';
  }

  // ---------------------------------------------------------------------------
  // Attachment extraction
  // ---------------------------------------------------------------------------

  _AttachmentInfo? _extractAttachment(
    Map<String, dynamic> msg,
    String baseDir,
  ) {
    // Photo message.
    final photo = msg['photo'] as String?;
    if (photo != null) {
      final sourcePath = p.join(baseDir, photo);
      final fileName = p.basename(photo);
      final fileSize = msg['photo_file_size'] as int?;
      return _AttachmentInfo(
        sourcePath: sourcePath,
        fileName: fileName,
        mediaType: 'image',
        mimeType: mimeTypeFromExtension(p.extension(fileName).replaceFirst('.', '')),
        fileSize: fileSize,
      );
    }

    // File / voice / video message.
    final filePath = msg['file'] as String?;
    if (filePath != null) {
      final sourcePath = p.join(baseDir, filePath);
      final fileName =
          (msg['file_name'] as String?) ?? p.basename(filePath);
      final fileSize = msg['file_size'] as int?;
      final mimeType = msg['mime_type'] as String?;

      // Determine if it's an image based on mime type.
      final isImage = mimeType != null && mimeType.startsWith('image/');

      return _AttachmentInfo(
        sourcePath: sourcePath,
        fileName: fileName,
        mediaType: isImage ? 'image' : 'file',
        mimeType: mimeType,
        fileSize: fileSize,
      );
    }

    return null;
  }

  Future<String?> _saveAttachmentFile(
    String sourcePath,
    String? fileName,
  ) async {
    final file = File(sourcePath);
    if (!await file.exists()) return null;

    try {
      return await _fileService.saveFile(sourcePath, fileName: fileName);
    } catch (e) {
      // File copy failed — skip silently.
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns a unique topic title by appending a suffix if [title] already
  /// exists in [existingNames] (case-insensitive).
  String _uniqueTitle(String title, Set<String> existingNames) {
    if (!existingNames.contains(title.toLowerCase())) return title;

    var counter = 2;
    while (existingNames.contains('${title.toLowerCase()} ($counter)')) {
      counter++;
    }
    return '$title ($counter)';
  }
}

/// Internal DTO for attachment info during Telegram import.
class _AttachmentInfo {
  final String sourcePath;
  final String? fileName;
  final String mediaType;
  final String? mimeType;
  final int? fileSize;

  const _AttachmentInfo({
    required this.sourcePath,
    this.fileName,
    required this.mediaType,
    this.mimeType,
    this.fileSize,
  });
}
