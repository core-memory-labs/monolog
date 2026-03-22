import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/topic_list_notifier.dart';
import '../providers/providers.dart';

/// Screen for saving shared content (image or text) from another app.
///
/// Shows a preview of the shared content, an optional caption field (for
/// images), and a list of topics. Tapping a topic saves the entry and
/// closes the screen. A new topic can be created inline — creating it also
/// saves the entry immediately.
///
/// [onDone] is called after saving or cancelling to let the parent handle
/// cleanup (reset share intent data, close app if cold start).
class ShareReceiverScreen extends ConsumerStatefulWidget {
  final String? sharedImagePath;
  final String? sharedText;
  final VoidCallback onDone;

  const ShareReceiverScreen({
    super.key,
    this.sharedImagePath,
    this.sharedText,
    required this.onDone,
  });

  @override
  ConsumerState<ShareReceiverScreen> createState() =>
      _ShareReceiverScreenState();
}

class _ShareReceiverScreenState extends ConsumerState<ShareReceiverScreen> {
  final _captionController = TextEditingController();
  final _newTopicController = TextEditingController();
  final _newTopicFocusNode = FocusNode();

  bool _isSaving = false;

  bool get _isImage => widget.sharedImagePath != null;

  @override
  void dispose() {
    _captionController.dispose();
    _newTopicController.dispose();
    _newTopicFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _saveToTopic(int topicId) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseServiceProvider);
      final content = _isImage
          ? _captionController.text.trim()
          : (widget.sharedText ?? '');

      // Create entry.
      final entry = await db.insertEntry(
        topicId: topicId,
        content: content,
      );

      // Save image if present.
      if (_isImage) {
        final imageService = ref.read(imageServiceProvider);
        final savedPath =
            await imageService.saveImage(widget.sharedImagePath!);
        await db.insertEntryImage(
          entryId: entry.id!,
          imagePath: savedPath,
          mediaType: 'image',
        );
      }

      // Refresh topic list so counters update.
      ref.invalidate(topicListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сохранено'),
            duration: Duration(milliseconds: 800),
          ),
        );

        // Pop this screen first, then let onDone handle app closure.
        Navigator.pop(context);
        widget.onDone();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _createTopicAndSave() async {
    final title = _newTopicController.text.trim();
    if (title.isEmpty) return;

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseServiceProvider);

      // Create the new topic.
      final topic = await db.insertTopic(title);

      // Save entry to the new topic.
      final content = _isImage
          ? _captionController.text.trim()
          : (widget.sharedText ?? '');

      final entry = await db.insertEntry(
        topicId: topic.id!,
        content: content,
      );

      if (_isImage) {
        final imageService = ref.read(imageServiceProvider);
        final savedPath =
            await imageService.saveImage(widget.sharedImagePath!);
        await db.insertEntryImage(
          entryId: entry.id!,
          imagePath: savedPath,
          mediaType: 'image',
        );
      }

      ref.invalidate(topicListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Сохранено в «$title»'),
            duration: const Duration(milliseconds: 800),
          ),
        );

        Navigator.pop(context);
        widget.onDone();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  void _cancel() {
    Navigator.pop(context);
    widget.onDone();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topicsAsync = ref.watch(topicListProvider);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          widget.onDone();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _cancel,
          ),
          title: const Text('Сохранить в…'),
        ),
        body: Column(
          children: [
            // Shared content preview
            _buildPreview(theme),

            const Divider(height: 1),

            // Topic list
            Expanded(
              child: topicsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text('Ошибка: $error')),
                data: (topics) {
                  if (topics.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Нет топиков.\nСоздайте новый для сохранения.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: topics.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final data = topics[index];
                      final topic = data.topic;

                      return ListTile(
                        leading: topic.isPinned
                            ? Icon(Icons.push_pin,
                                size: 20,
                                color: theme.colorScheme.primary)
                            : const SizedBox(width: 20),
                        title: Text(
                          topic.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right),
                        enabled: !_isSaving,
                        onTap: () => _saveToTopic(topic.id!),
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // New topic creation
            _buildNewTopicInput(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image preview
          if (_isImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: Image.file(
                  File(widget.sharedImagePath!),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, size: 32),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _captionController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: 'Подпись (необязательно)…',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
          ],

          // Text preview
          if (!_isImage && widget.sharedText != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.sharedText!,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNewTopicInput(ThemeData theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newTopicController,
                focusNode: _newTopicFocusNode,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  hintText: 'Новый топик…',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                onSubmitted: (_) => _createTopicAndSave(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isSaving ? null : _createTopicAndSave,
              icon: const Icon(Icons.add),
              tooltip: 'Создать и сохранить',
            ),
          ],
        ),
      ),
    );
  }
}
