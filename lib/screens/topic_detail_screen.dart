import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/topic_list_notifier.dart';
import '../utils/date_format.dart';
import '../widgets/topic_avatar.dart';
import '../widgets/topic_edit_sheet.dart';

/// Telegram-style topic detail screen.
///
/// Shows a large avatar, topic name, and stats in the top section.
/// The bottom section is a placeholder for future tabs (media gallery,
/// files, links).
///
/// Tapping the edit button (✏️) opens [TopicEditSheet] to change the
/// topic's name and icon.
class TopicDetailScreen extends ConsumerWidget {
  final int topicId;

  const TopicDetailScreen({super.key, required this.topicId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicListProvider);

    return topicsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Ошибка: $error')),
      ),
      data: (topics) {
        final data = topics.where((t) => t.topic.id == topicId).firstOrNull;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Топик не найден')),
          );
        }

        final topic = data.topic;

        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Редактировать',
                onPressed: () => _openEditSheet(context, ref, topic.title, topic.icon),
              ),
            ],
          ),
          body: Column(
            children: [
              // --- Top section: avatar + name + stats ---
              _TopicInfoSection(
                title: topic.title,
                icon: topic.icon,
                entryCount: data.entryCount,
                createdAt: topic.createdAt,
              ),

              const Divider(height: 1),

              // --- Bottom section: future tabs placeholder ---
              const Expanded(
                child: _TopicMediaSection(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditSheet(
    BuildContext context,
    WidgetRef ref,
    String currentTitle,
    String? currentIcon,
  ) async {
    final result = await showModalBottomSheet<TopicEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TopicEditSheet(
        currentTitle: currentTitle,
        currentIcon: currentIcon,
      ),
    );

    if (result == null) return;

    final notifier = ref.read(topicListProvider.notifier);

    // Update title if changed.
    if (result.title != currentTitle) {
      await notifier.renameTopic(topicId, result.title);
    }

    // Update icon if changed.
    if (result.icon != currentIcon) {
      await notifier.setTopicIcon(topicId, result.icon);
    }
  }
}

/// Top section of the detail screen: large avatar, title, stats.
class _TopicInfoSection extends StatelessWidget {
  final String title;
  final String? icon;
  final int entryCount;
  final DateTime createdAt;

  const _TopicInfoSection({
    required this.title,
    this.icon,
    required this.entryCount,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          TopicAvatar(title: title, icon: icon, size: 80),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            '${_pluralEntries(entryCount)} · создан ${formatRelativeDate(createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

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

/// Placeholder for future media/files/links tabs.
///
/// Will be replaced with [TabBar] + [TabBarView] containing:
/// - Media gallery (images)
/// - Files list
/// - Links list
class _TopicMediaSection extends StatelessWidget {
  const _TopicMediaSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.perm_media_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'Медиа и файлы',
            style: theme.textTheme.bodyMedium?.copyWith(
              color:
                  theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
