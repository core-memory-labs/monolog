/// Represents an image (or future media) attached to an [Entry].
///
/// Stored in the `entry_images` table. Multiple images per entry are supported
/// at the schema level; Stage 3.1 UI limits this to one.
class EntryImage {
  final int? id;
  final int entryId;
  final String imagePath;
  final String mediaType;
  final int sortOrder;
  final DateTime createdAt;

  const EntryImage({
    this.id,
    required this.entryId,
    required this.imagePath,
    this.mediaType = 'image',
    this.sortOrder = 0,
    required this.createdAt,
  });

  EntryImage copyWith({
    int? id,
    int? entryId,
    String? imagePath,
    String? mediaType,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return EntryImage(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      imagePath: imagePath ?? this.imagePath,
      mediaType: mediaType ?? this.mediaType,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'entry_id': entryId,
      'image_path': imagePath,
      'media_type': mediaType,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory EntryImage.fromMap(Map<String, dynamic> map) {
    return EntryImage(
      id: map['id'] as int,
      entryId: map['entry_id'] as int,
      imagePath: map['image_path'] as String,
      mediaType: map['media_type'] as String,
      sortOrder: map['sort_order'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  String toString() =>
      'EntryImage(id: $id, entryId: $entryId, mediaType: $mediaType)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntryImage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
