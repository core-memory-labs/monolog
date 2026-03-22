import 'package:flutter/material.dart';

import '../models/topic_with_stats.dart';
import '../utils/date_format.dart';

/// A single topic row in the topic list.
///
/// Shows: title, entry count, last activity date, and a pin indicator.
/// [onTap] is called for navigation, [onLongPress] to enter selection mode.
/// When [isSelected] is true the tile gets a highlighted background.
class TopicTile extends StatelessWidget {
  final TopicWithStats data;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const TopicTile({
    super.key,
    required this.data,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topic = data.topic;

    final countLabel = _pluralEntries(data.entryCount);
    final dateLabel = formatRelativeDate(data.lastActivity);

    return ListTile(
      selected: isSelected,
      selectedTileColor:
          theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      leading: topic.isPinned
          ? Icon(Icons.push_pin, size: 20, color: theme.colorScheme.primary)
          : const SizedBox(width: 20),
      title: Text(
        topic.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('$countLabel · $dateLabel'),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  /// Russian pluralisation for "записей".
  static String _pluralEntries(int count) {
    if (count == 0) return 'Нет записей';

    final mod10 = count % 10;
    final mod100 = count % 100;

    if (mod10 == 1 && mod100 != 11) return '$count запись';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return '$count записи';
    }
    return '$count записей';
  }
}
