class Topic {
  final int? id;
  final String title;
  final bool isPinned;
  final String? icon;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Topic({
    this.id,
    required this.title,
    this.isPinned = false,
    this.icon,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether the user has set a custom emoji icon.
  bool get hasCustomIcon => icon != null && icon!.isNotEmpty;

  Topic copyWith({
    int? id,
    String? title,
    bool? isPinned,
    String? Function()? icon,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Topic(
      id: id ?? this.id,
      title: title ?? this.title,
      isPinned: isPinned ?? this.isPinned,
      icon: icon != null ? icon() : this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'is_pinned': isPinned ? 1 : 0,
      'icon': icon,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Topic.fromMap(Map<String, dynamic> map) {
    return Topic(
      id: map['id'] as int,
      title: map['title'] as String,
      isPinned: (map['is_pinned'] as int) == 1,
      icon: map['icon'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  String toString() =>
      'Topic(id: $id, title: $title, isPinned: $isPinned, icon: $icon)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Topic && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
