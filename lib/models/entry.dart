class Entry {
  final int? id;
  final int topicId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Entry({
    this.id,
    required this.topicId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  Entry copyWith({
    int? id,
    int? topicId,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Entry(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'topic_id': topicId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Entry.fromMap(Map<String, dynamic> map) {
    return Entry(
      id: map['id'] as int,
      topicId: map['topic_id'] as int,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  String toString() =>
      'Entry(id: $id, topicId: $topicId, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entry && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
