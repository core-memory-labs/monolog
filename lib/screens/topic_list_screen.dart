import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/topic_list_notifier.dart';
import '../widgets/topic_actions_sheet.dart';
import '../widgets/topic_tile.dart';

/// Main screen — displays all topics with an inline input field at the bottom
/// for quick topic creation.
class TopicListScreen extends ConsumerStatefulWidget {
  const TopicListScreen({super.key});

  @override
  ConsumerState<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends ConsumerState<TopicListScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _createTopic() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    _controller.clear();
    _focusNode.unfocus();
    await ref.read(topicListProvider.notifier).addTopic(title);
  }

  Future<void> _onTopicTap(int topicId) async {
    // TODO: Navigate to entries screen (Stage 3).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Экран записей — следующий этап'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _onTopicLongPress(BuildContext context, int topicId) async {
    final topics = ref.read(topicListProvider).valueOrNull;
    final data = topics?.firstWhere((t) => t.topic.id == topicId);
    if (data == null) return;

    final action = await showTopicActionsSheet(context, topic: data.topic);
    if (action == null || !context.mounted) return;

    switch (action) {
      case TopicAction.rename:
        final newTitle = await showRenameDialog(
          context,
          currentTitle: data.topic.title,
        );
        if (newTitle != null && newTitle != data.topic.title) {
          await ref.read(topicListProvider.notifier).renameTopic(
                topicId,
                newTitle,
              );
        }
      case TopicAction.togglePin:
        await ref.read(topicListProvider.notifier).togglePin(
              topicId,
              isPinned: !data.topic.isPinned,
            );
      case TopicAction.delete:
        final confirmed = await showDeleteConfirmation(
          context,
          topicTitle: data.topic.title,
        );
        if (confirmed == true) {
          await ref.read(topicListProvider.notifier).deleteTopic(topicId);
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Monolog')),
      body: Column(
        children: [
          // Topic list
          Expanded(
            child: topicsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Ошибка: $error')),
              data: (topics) {
                if (topics.isEmpty) {
                  return const Center(
                    child: Text('Нет топиков.\nСоздайте первый!',
                        textAlign: TextAlign.center),
                  );
                }

                return ListView.separated(
                  itemCount: topics.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = topics[index];
                    return TopicTile(
                      data: data,
                      onTap: () => _onTopicTap(data.topic.id!),
                      onLongPress: () =>
                          _onTopicLongPress(context, data.topic.id!),
                    );
                  },
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Inline topic creation input
          _TopicInput(
            controller: _controller,
            focusNode: _focusNode,
            onSubmit: _createTopic,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Inline input widget
// -----------------------------------------------------------------------------

class _TopicInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  const _TopicInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Новый топик…',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onSubmit,
              icon: const Icon(Icons.add),
              tooltip: 'Создать топик',
            ),
          ],
        ),
      ),
    );
  }
}
