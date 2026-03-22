/// Cached link preview data (OpenGraph metadata) for a URL.
///
/// Stored in the `link_previews` table. A record with [title] == null
/// represents a failed fetch attempt — the card is not displayed.
class LinkPreview {
  final int? id;
  final String url;
  final String? title;
  final String? description;

  /// Original remote URL of the OG image.
  final String? imageUrl;

  /// Local path to the cached OG image on disk.
  final String? imagePath;

  /// Site name from `og:site_name` meta tag.
  final String? siteName;

  final DateTime fetchedAt;

  const LinkPreview({
    this.id,
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.imagePath,
    this.siteName,
    required this.fetchedAt,
  });

  /// Whether a local cached image is available.
  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;

  /// Whether this preview has enough data to display a card.
  bool get isValid => title != null && title!.isNotEmpty;

  LinkPreview copyWith({
    int? id,
    String? url,
    String? title,
    String? description,
    String? imageUrl,
    String? imagePath,
    String? siteName,
    DateTime? fetchedAt,
  }) {
    return LinkPreview(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      siteName: siteName ?? this.siteName,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'url': url,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'image_path': imagePath,
      'site_name': siteName,
      'fetched_at': fetchedAt.toIso8601String(),
    };
  }

  factory LinkPreview.fromMap(Map<String, dynamic> map) {
    return LinkPreview(
      id: map['id'] as int,
      url: map['url'] as String,
      title: map['title'] as String?,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      imagePath: map['image_path'] as String?,
      siteName: map['site_name'] as String?,
      fetchedAt: DateTime.parse(map['fetched_at'] as String),
    );
  }

  @override
  String toString() =>
      'LinkPreview(id: $id, url: $url, title: $title, siteName: $siteName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkPreview &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
