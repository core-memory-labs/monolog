/// A single result from full-text search across entries.
///
/// Contains enough data to display the result card and navigate to the
/// entry within its topic.
class SearchResult {
  final int entryId;
  final int topicId;
  final String topicTitle;
  final String content;
  final DateTime createdAt;

  const SearchResult({
    required this.entryId,
    required this.topicId,
    required this.topicTitle,
    required this.content,
    required this.createdAt,
  });

  factory SearchResult.fromMap(Map<String, dynamic> map) {
    return SearchResult(
      entryId: map['id'] as int,
      topicId: map['topic_id'] as int,
      topicTitle: map['topic_title'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  String toString() =>
      'SearchResult(entryId: $entryId, topicId: $topicId, topicTitle: $topicTitle)';
}
