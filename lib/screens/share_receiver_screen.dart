import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../providers/entry_list_notifier.dart';
import '../providers/topic_list_notifier.dart';
import '../providers/providers.dart';
import '../utils/file_utils.dart';
import '../widgets/file_card.dart';
import '../widgets/topic_avatar.dart';

/// Screen for saving shared content (image, file, or text) from another app.
///
/// Shows a preview of the shared content, an optional caption field (for
/// images/files), and a list of topics. Tapping a topic saves the entry and
/// closes the screen. A new topic can be created inline — creating it also
/// saves the entry immediately.
///
/// [onDone] is called after saving or cancelling to let the parent handle
/// cleanup (reset share intent data, close app if cold start).
///
/// Note: [onDone] must NOT be called explicitly alongside [Navigator.pop] —
/// the [PopScope] wrapper calls it automatically on any pop event.
class ShareReceiverScreen extends ConsumerStatefulWidget {
  final String? sharedImagePath;
  final String? sharedText;
  final String? sharedFilePath;
  final String? sharedFileMimeType;
  final VoidCallback onDone;

  const ShareReceiverScreen({
    super.key,
    this.sharedImagePath,
    this.sharedText,
    this.sharedFilePath,
    this.sharedFileMimeType,
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
  bool get _isFile => widget.sharedFilePath != null;
  bool get _isText => !_isImage && !_isFile;

  String? get _sharedFileName =>
      widget.sharedFilePath != null
          ? p.basename(widget.sharedFilePath!)
          : null;

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
      final fileService = ref.read(fileServiceProvider);

      // Determine content text.
      final content = _isText
          ? (widget.sharedText ?? '')
          : _captionController.text.trim();

      // Create entry.
      final entry = await db.insertEntry(
        topicId: topicId,
        content: content,
      );

      // Save image if present.
      if (_isImage) {
        final savedPath =
            await fileService.saveFile(widget.sharedImagePath!);
        await db.insertEntryAttachment(
          entryId: entry.id!,
          filePath: savedPath,
          mediaType: 'image',
        );
      }

      // Save file if present (non-image).
      if (_isFile) {
        final savedPath = await fileService.saveFile(
          widget.sharedFilePath!,
          fileName: _sharedFileName,
        );
        final fileSize =
            await fileService.getFileSize(savedPath);
        await db.insertEntryAttachment(
          entryId: entry.id!,
          filePath: savedPath,
          mediaType: 'file',
          fileName: _sharedFileName,
          fileSize: fileSize > 0 ? fileSize : null,
          mimeType: widget.sharedFileMimeType,
        );
      }

      // Refresh topic list counters and the entry feed for the target topic.
      // Without invalidating entryListProvider the feed would show stale data
      // until the user manually adds another entry.
      ref.invalidate(topicListProvider);
      ref.invalidate(entryListProvider(topicId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сохранено'),
            duration: Duration(milliseconds: 800),
          ),
        );

        // Pop this screen. PopScope.onPopInvokedWithResult will call onDone —
        // do NOT call it again here or it fires twice.
        Navigator.pop(context);
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
      final fileService = ref.read(fileServiceProvider);

      // Create the new topic.
      final topic = await db.insertTopic(title);

      // Determine content text.
      final content = _isText
          ? (widget.sharedText ?? '')
          : _captionController.text.trim();

      final entry = await db.insertEntry(
        topicId: topic.id!,
        content: content,
      );

      if (_isImage) {
        final savedPath =
            await fileService.saveFile(widget.sharedImagePath!);
        await db.insertEntryAttachment(
          entryId: entry.id!,
          filePath: savedPath,
          mediaType: 'image',
        );
      }

      if (_isFile) {
        final savedPath = await fileService.saveFile(
          widget.sharedFilePath!,
          fileName: _sharedFileName,
        );
        final fileSize =
            await fileService.getFileSize(savedPath);
        await db.insertEntryAttachment(
          entryId: entry.id!,
          filePath: savedPath,
          mediaType: 'file',
          fileName: _sharedFileName,
          fileSize: fileSize > 0 ? fileSize : null,
          mimeType: widget.sharedFileMimeType,
        );
      }

      // Refresh topic list counters and the entry feed for the new topic.
      ref.invalidate(topicListProvider);
      ref.invalidate(entryListProvider(topic.id!));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Сохранено в «$title»'),
            duration: const Duration(milliseconds: 800),
          ),
        );

        // Pop this screen. PopScope.onPopInvokedWithResult will call onDone.
        Navigator.pop(context);
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
    // Pop this screen. PopScope.onPopInvokedWithResult will call onDone.
    Navigator.pop(context);
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
                        leading: TopicAvatar(
                          title: topic.title,
                          icon: topic.icon,
                          size: 40,
                        ),
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
            _buildCaptionField(),
          ],

          // File preview (non-image)
          if (_isFile) ...[
            FileCard(
              fileName: _sharedFileName,
              mimeType: widget.sharedFileMimeType,
            ),
            const SizedBox(height: 12),
            _buildCaptionField(),
          ],

          // Text preview
          if (_isText && widget.sharedText != null)
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

  Widget _buildCaptionField() {
    return TextField(
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
