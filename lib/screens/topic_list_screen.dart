import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/topic_list_notifier.dart';
import '../utils/dialogs.dart';
import '../widgets/topic_tile.dart';
import 'entry_list_screen.dart';
import 'search_screen.dart';

/// Main screen — displays all topics with an inline input field at the bottom
/// for quick topic creation.
///
/// Long press on a topic enters selection mode: the AppBar changes to show
/// contextual actions (pin, edit, delete). A search icon (🔍) in the AppBar
/// opens the full-text search screen.
class TopicListScreen extends ConsumerStatefulWidget {
  const TopicListScreen({super.key});

  @override
  ConsumerState<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends ConsumerState<TopicListScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  /// Currently selected topic ID, or `null` when not in selection mode.
  int? _selectedTopicId;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearSelection() {
    setState(() => _selectedTopicId = null);
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

  void _onTopicTap(int topicId, String topicTitle) {
    // In selection mode, tap toggles selection.
    if (_selectedTopicId != null) {
      setState(() {
        _selectedTopicId = _selectedTopicId == topicId ? null : topicId;
      });
      return;
    }

    // Normal mode — navigate to entry feed.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryListScreen(
          topicId: topicId,
          topicTitle: topicTitle,
        ),
      ),
    );
  }

  void _onTopicLongPress(int topicId) {
    setState(() => _selectedTopicId = topicId);
  }

  Future<void> _togglePinSelectedTopic() async {
    final topicId = _selectedTopicId;
    if (topicId == null) return;

    final topics = ref.read(topicListProvider).valueOrNull;
    final data = topics?.firstWhere((t) => t.topic.id == topicId);
    if (data == null) return;

    _clearSelection();
    await ref.read(topicListProvider.notifier).togglePin(
          topicId,
          isPinned: !data.topic.isPinned,
        );
  }

  Future<void> _editSelectedTopic() async {
    final topicId = _selectedTopicId;
    if (topicId == null) return;

    final topics = ref.read(topicListProvider).valueOrNull;
    final data = topics?.firstWhere((t) => t.topic.id == topicId);
    if (data == null) return;

    _clearSelection();

    final newTitle = await showEditDialog(
      context,
      currentTitle: data.topic.title,
    );
    if (newTitle != null && newTitle != data.topic.title) {
      await ref.read(topicListProvider.notifier).renameTopic(
            topicId,
            newTitle,
          );
    }
  }

  Future<void> _deleteSelectedTopic() async {
    final topicId = _selectedTopicId;
    if (topicId == null) return;

    final topics = ref.read(topicListProvider).valueOrNull;
    final data = topics?.firstWhere((t) => t.topic.id == topicId);
    if (data == null) return;

    final confirmed = await showDeleteConfirmation(
      context,
      title: 'Удалить топик?',
      message:
          'Топик «${data.topic.title}» и все его записи будут удалены безвозвратно.',
    );
    if (confirmed == true) {
      _clearSelection();
      await ref.read(topicListProvider.notifier).deleteTopic(topicId);
    }
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar() {
    if (_selectedTopicId != null) {
      final topics = ref.read(topicListProvider).valueOrNull;
      final data = topics?.firstWhere((t) => t.topic.id == _selectedTopicId);
      final isPinned = data?.topic.isPinned ?? false;

      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
        ),
        title: Text(
          data?.topic.title ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            tooltip: isPinned ? 'Открепить' : 'Закрепить',
            onPressed: _togglePinSelectedTopic,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Редактировать',
            onPressed: _editSelectedTopic,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Удалить',
            onPressed: _deleteSelectedTopic,
          ),
        ],
      );
    }

    return AppBar(
      title: const Text('Monolog'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Поиск',
          onPressed: _openSearch,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicListProvider);

    return PopScope(
      canPop: _selectedTopicId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // Topic list
            Expanded(
              child: topicsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text('Ошибка: $error')),
                data: (topics) {
                  if (topics.isEmpty) {
                    return const Center(
                      child: Text(
                        'Нет топиков.\nСоздайте первый!',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: topics.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final data = topics[index];
                      return TopicTile(
                        data: data,
                        isSelected: data.topic.id == _selectedTopicId,
                        onTap: () =>
                            _onTopicTap(data.topic.id!, data.topic.title),
                        onLongPress: () =>
                            _onTopicLongPress(data.topic.id!),
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
