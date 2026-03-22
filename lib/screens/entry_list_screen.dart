import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../models/entry_with_attachment.dart';
import '../providers/entry_list_notifier.dart';
import '../utils/dialogs.dart';
import '../utils/file_utils.dart';
import '../widgets/entry_bubble.dart';
import '../widgets/entry_input.dart';
import 'image_viewer_screen.dart';

/// Displays the feed of entries within a topic.
///
/// Features:
/// - Entries ordered newest-first, with optional image previews or file cards.
/// - Multiline messenger-style input with 📎 for attachments (gallery/camera/file).
/// - Long press → contextual AppBar with edit / copy / share / delete.
/// - Inline editing with attachment replace / remove support.
/// - Tap on image → fullscreen viewer. Tap on file → system app.
class EntryListScreen extends ConsumerStatefulWidget {
  final int topicId;
  final String topicTitle;

  const EntryListScreen({
    super.key,
    required this.topicId,
    required this.topicTitle,
  });

  @override
  ConsumerState<EntryListScreen> createState() => _EntryListScreenState();
}

class _EntryListScreenState extends ConsumerState<EntryListScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _imagePicker = ImagePicker();

  /// Non-null when an entry is selected via long press (contextual AppBar).
  int? _selectedEntryId;

  /// Non-null when the user is editing an existing entry (inline in input).
  int? _editingEntryId;

  /// Info about the currently attached file in the input (new or existing).
  AttachmentInfo? _attachedFile;

  /// Attachment info when editing started — used to detect changes on submit.
  AttachmentInfo? _originalFile;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearSelection() {
    setState(() => _selectedEntryId = null);
  }

  void _cancelEdit() {
    setState(() {
      _editingEntryId = null;
      _attachedFile = null;
      _originalFile = null;
    });
    _controller.clear();
    _focusNode.unfocus();
  }

  // ---------------------------------------------------------------------------
  // Attachment picking
  // ---------------------------------------------------------------------------

  Future<void> _pickAttachment() async {
    final choice = await showModalBottomSheet<_AttachmentChoice>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Галерея'),
              onTap: () => Navigator.pop(ctx, _AttachmentChoice.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Камера'),
              onTap: () => Navigator.pop(ctx, _AttachmentChoice.camera),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Файл'),
              onTap: () => Navigator.pop(ctx, _AttachmentChoice.file),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    switch (choice) {
      case _AttachmentChoice.gallery:
      case _AttachmentChoice.camera:
        final source = choice == _AttachmentChoice.gallery
            ? ImageSource.gallery
            : ImageSource.camera;
        final picked = await _imagePicker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (picked != null) {
          setState(() => _attachedFile = AttachmentInfo(
                path: picked.path,
                isImage: true,
                mimeType: 'image/jpeg',
              ));
        }
      case _AttachmentChoice.file:
        final result = await FilePicker.platform.pickFiles();
        if (result != null && result.files.single.path != null) {
          final file = result.files.single;
          final isImage = isImageExtension(file.extension);
          setState(() => _attachedFile = AttachmentInfo(
                path: file.path!,
                isImage: isImage,
                fileName: file.name,
                fileSize: file.size,
                mimeType: mimeTypeFromExtension(file.extension),
              ));
        }
    }
  }

  void _removeAttachment() {
    setState(() => _attachedFile = null);
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _submitEntry() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachedFile == null) return;

    final notifier = ref.read(entryListProvider(widget.topicId).notifier);

    if (_editingEntryId != null) {
      // Determine attachment changes.
      final attachmentChanged = _attachedFile?.path != _originalFile?.path;
      if (attachmentChanged) {
        await notifier.updateEntry(
          _editingEntryId!,
          text,
          newFilePath: _attachedFile?.path,
          removeAttachment: _originalFile != null,
          mediaType: _attachedFile?.isImage == true ? 'image' : 'file',
          fileName: _attachedFile?.fileName,
          fileSize: _attachedFile?.fileSize,
          mimeType: _attachedFile?.mimeType,
        );
      } else {
        await notifier.updateEntry(_editingEntryId!, text);
      }
    } else {
      await notifier.addEntry(
        text,
        filePath: _attachedFile?.path,
        mediaType: _attachedFile?.isImage == true ? 'image' : 'file',
        fileName: _attachedFile?.fileName,
        fileSize: _attachedFile?.fileSize,
        mimeType: _attachedFile?.mimeType,
      );
    }

    _controller.clear();
    _focusNode.unfocus();
    setState(() {
      _editingEntryId = null;
      _attachedFile = null;
      _originalFile = null;
    });
  }

  void _startEdit() {
    final entries =
        ref.read(entryListProvider(widget.topicId)).valueOrNull;
    if (entries == null || _selectedEntryId == null) return;

    final data = entries.firstWhere((e) => e.entry.id == _selectedEntryId);
    final att = data.firstAttachment;

    AttachmentInfo? fileInfo;
    if (att != null) {
      fileInfo = AttachmentInfo(
        path: att.filePath,
        isImage: att.isImage,
        fileName: att.fileName,
        fileSize: att.fileSize,
        mimeType: att.mimeType,
      );
    }

    setState(() {
      _editingEntryId = _selectedEntryId;
      _selectedEntryId = null;
      _attachedFile = fileInfo;
      _originalFile = fileInfo;
    });

    _controller.text = data.entry.content;
    _controller.selection =
        TextSelection.collapsed(offset: data.entry.content.length);
    _focusNode.requestFocus();
  }

  Future<void> _copyEntry() async {
    final entries =
        ref.read(entryListProvider(widget.topicId)).valueOrNull;
    if (entries == null || _selectedEntryId == null) return;

    final data = entries.firstWhere((e) => e.entry.id == _selectedEntryId);
    await Clipboard.setData(ClipboardData(text: data.entry.content));
    _clearSelection();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Скопировано'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _shareEntry() async {
    final entries =
        ref.read(entryListProvider(widget.topicId)).valueOrNull;
    if (entries == null || _selectedEntryId == null) return;

    final data = entries.firstWhere((e) => e.entry.id == _selectedEntryId);
    _clearSelection();

    // Share file + text or just text.
    final filePath = data.firstFilePath;
    if (filePath != null) {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: data.entry.content.isNotEmpty ? data.entry.content : null,
      );
    } else {
      await Share.share(data.entry.content);
    }
  }

  Future<void> _deleteEntry() async {
    if (_selectedEntryId == null) return;

    final confirmed = await showDeleteConfirmation(
      context,
      title: 'Удалить запись?',
      message: 'Запись будет удалена безвозвратно.',
    );

    if (confirmed == true) {
      final entryId = _selectedEntryId!;
      _clearSelection();
      await ref
          .read(entryListProvider(widget.topicId).notifier)
          .deleteEntry(entryId);
    }
  }

  void _openImageViewer(EntryWithAttachment data) {
    final imagePath = data.firstFilePath;
    if (imagePath == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(
          imagePath: imagePath,
          entryId: data.entry.id!,
          topicId: widget.topicId,
        ),
      ),
    );
  }

  Future<void> _openFile(EntryWithAttachment data) async {
    final att = data.firstAttachment;
    if (att == null) return;

    await OpenFilex.open(att.filePath, type: att.mimeType);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar() {
    if (_selectedEntryId != null) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Редактировать',
            onPressed: _startEdit,
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Копировать',
            onPressed: _copyEntry,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Поделиться',
            onPressed: _shareEntry,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Удалить',
            onPressed: _deleteEntry,
          ),
        ],
      );
    }

    return AppBar(title: Text(widget.topicTitle));
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(entryListProvider(widget.topicId));

    return PopScope(
      canPop: _selectedEntryId == null && _editingEntryId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_editingEntryId != null) {
          _cancelEdit();
        } else {
          _clearSelection();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // Entry feed
            Expanded(
              child: entriesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text('Ошибка: $error')),
                data: (entries) {
                  if (entries.isEmpty) {
                    return const Center(
                      child: Text(
                        'Нет записей.\nНапишите первую!',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final data = entries[index];
                      return EntryBubble(
                        data: data,
                        isSelected: data.entry.id == _selectedEntryId,
                        onLongPress: () {
                          if (_editingEntryId != null) _cancelEdit();
                          setState(
                              () => _selectedEntryId = data.entry.id);
                        },
                        onImageTap: () => _openImageViewer(data),
                        onFileTap: () => _openFile(data),
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Input field
            EntryInput(
              controller: _controller,
              focusNode: _focusNode,
              onSubmit: _submitEntry,
              isEditing: _editingEntryId != null,
              onCancelEdit: _cancelEdit,
              attachedFile: _attachedFile,
              onPickAttachment: _pickAttachment,
              onRemoveAttachment: _removeAttachment,
            ),
          ],
        ),
      ),
    );
  }
}

enum _AttachmentChoice { gallery, camera, file }
