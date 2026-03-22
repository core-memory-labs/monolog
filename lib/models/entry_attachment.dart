/// Represents a file attachment (image or any file) attached to an [Entry].
///
/// Stored in the `entry_attachments` table (renamed from `entry_images` in v3).
/// Multiple attachments per entry are supported at the schema level;
/// the UI limits this to one.
class EntryAttachment {
  final int? id;
  final int entryId;

  /// Path to the file on disk. Maps to the `image_path` DB column
  /// (column name kept for backward compatibility with SQLite < 3.25).
  final String filePath;

  /// Broad category: `'image'` or `'file'`. Determines UI rendering.
  final String mediaType;

  final int sortOrder;
  final DateTime createdAt;

  /// Original file name (e.g. `report.pdf`). Null for legacy image entries.
  final String? fileName;

  /// File size in bytes. Null for legacy image entries.
  final int? fileSize;

  /// Specific MIME type (e.g. `application/pdf`, `image/jpeg`).
  /// Null for legacy image entries.
  final String? mimeType;

  const EntryAttachment({
    this.id,
    required this.entryId,
    required this.filePath,
    this.mediaType = 'image',
    this.sortOrder = 0,
    required this.createdAt,
    this.fileName,
    this.fileSize,
    this.mimeType,
  });

  /// Whether this attachment is an image (preview + fullscreen viewer).
  bool get isImage => mediaType == 'image';

  EntryAttachment copyWith({
    int? id,
    int? entryId,
    String? filePath,
    String? mediaType,
    int? sortOrder,
    DateTime? createdAt,
    String? fileName,
    int? fileSize,
    String? mimeType,
  }) {
    return EntryAttachment(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      filePath: filePath ?? this.filePath,
      mediaType: mediaType ?? this.mediaType,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'entry_id': entryId,
      'image_path': filePath, // DB column kept as image_path
      'media_type': mediaType,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
    };
  }

  factory EntryAttachment.fromMap(Map<String, dynamic> map) {
    return EntryAttachment(
      id: map['id'] as int,
      entryId: map['entry_id'] as int,
      filePath: map['image_path'] as String, // DB column kept as image_path
      mediaType: map['media_type'] as String,
      sortOrder: map['sort_order'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      fileName: map['file_name'] as String?,
      fileSize: map['file_size'] as int?,
      mimeType: map['mime_type'] as String?,
    );
  }

  @override
  String toString() =>
      'EntryAttachment(id: $id, entryId: $entryId, mediaType: $mediaType, fileName: $fileName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntryAttachment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
