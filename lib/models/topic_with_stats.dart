import 'topic.dart';

/// A [Topic] enriched with aggregate data needed for the topic list screen.
class TopicWithStats {
  final Topic topic;
  final int entryCount;
  final DateTime lastActivity;

  const TopicWithStats({
    required this.topic,
    required this.entryCount,
    required this.lastActivity,
  });
}
