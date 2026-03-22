import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// AttachmentInfo — UI-layer DTO for tracking attachments in input widgets
// ---------------------------------------------------------------------------

/// Temporary data about an attachment being composed in the input field.
///
/// Not persisted — used only for passing info between [EntryInput] and
/// [EntryListScreen] during creation / editing.
class AttachmentInfo {
  final String path;
  final bool isImage;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;

  const AttachmentInfo({
    required this.path,
    required this.isImage,
    this.fileName,
    this.fileSize,
    this.mimeType,
  });
}

// ---------------------------------------------------------------------------
// MIME type detection from file extension
// ---------------------------------------------------------------------------

/// Returns the MIME type for a file extension (without dot), or
/// `application/octet-stream` for unknown extensions.
String mimeTypeFromExtension(String? extension) {
  if (extension == null || extension.isEmpty) return 'application/octet-stream';
  final ext = extension.toLowerCase();
  return switch (ext) {
    // Images
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'bmp' => 'image/bmp',
    'svg' => 'image/svg+xml',
    // Documents
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    // Archives
    'zip' => 'application/zip',
    'rar' => 'application/x-rar-compressed',
    '7z' => 'application/x-7z-compressed',
    'tar' => 'application/x-tar',
    'gz' => 'application/gzip',
    // Text
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    'json' => 'application/json',
    'xml' => 'application/xml',
    'html' || 'htm' => 'text/html',
    'md' => 'text/markdown',
    // Audio
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'ogg' => 'audio/ogg',
    'flac' => 'audio/flac',
    'aac' => 'audio/aac',
    // Video
    'mp4' => 'video/mp4',
    'avi' => 'video/x-msvideo',
    'mkv' => 'video/x-matroska',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    // Other
    'apk' => 'application/vnd.android.package-archive',
    _ => 'application/octet-stream',
  };
}

// ---------------------------------------------------------------------------
// Image extension detection
// ---------------------------------------------------------------------------

/// Common image file extensions.
const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

/// Returns `true` if [extension] (without dot) is a recognized image format.
bool isImageExtension(String? extension) {
  if (extension == null) return false;
  return _imageExtensions.contains(extension.toLowerCase());
}

// ---------------------------------------------------------------------------
// Icon for MIME type
// ---------------------------------------------------------------------------

/// Returns a Material icon appropriate for the given [mimeType].
IconData iconForMimeType(String? mimeType) {
  if (mimeType == null) return Icons.insert_drive_file;
  if (mimeType.startsWith('image/')) return Icons.image;
  if (mimeType.startsWith('video/')) return Icons.video_file;
  if (mimeType.startsWith('audio/')) return Icons.audio_file;
  if (mimeType.startsWith('text/')) return Icons.text_snippet;
  if (mimeType == 'application/pdf') return Icons.picture_as_pdf;
  if (mimeType.contains('zip') ||
      mimeType.contains('rar') ||
      mimeType.contains('7z') ||
      mimeType.contains('tar') ||
      mimeType.contains('gzip')) {
    return Icons.folder_zip;
  }
  if (mimeType.contains('word') || mimeType.contains('document')) {
    return Icons.description;
  }
  if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
    return Icons.table_chart;
  }
  if (mimeType.contains('powerpoint') || mimeType.contains('presentation')) {
    return Icons.slideshow;
  }
  return Icons.insert_drive_file;
}

// ---------------------------------------------------------------------------
// File size formatting
// ---------------------------------------------------------------------------

/// Formats [bytes] as a human-readable string: «1.2 МБ», «350 КБ», etc.
String formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';

  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;

  if (bytes < kb) return '$bytes Б';
  if (bytes < mb) return '${(bytes / kb).toStringAsFixed(1)} КБ';
  if (bytes < gb) return '${(bytes / mb).toStringAsFixed(1)} МБ';
  return '${(bytes / gb).toStringAsFixed(1)} ГБ';
}
