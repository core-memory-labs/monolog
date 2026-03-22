import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/entry_list_notifier.dart';
import '../utils/dialogs.dart';
import '../widgets/entry_bubble.dart';
import '../widgets/entry_input.dart';

/// Displays the feed of entries within a topic.
///
/// Features:
/// - Entries ordered newest-first.
/// - Multiline messenger-style input at the bottom.
/// - Long press → contextual AppBar with edit / copy / share / delete.
/// - Inline editing: text loads into the input field.
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

  /// Non-null when an entry is selected via long press (contextual AppBar).
  int? _selectedEntryId;

  /// Non-null when the user is editing an existing entry (inline in input).
  int? _editingEntryId;

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
    setState(() => _editingEntryId = null);
    _controller.clear();
    _focusNode.unfocus();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _submitEntry() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final notifier = ref.read(entryListProvider(widget.topicId).notifier);

    if (_editingEntryId != null) {
      await notifier.updateEntry(_editingEntryId!, text);
      setState(() => _editingEntryId = null);
    } else {
      await notifier.addEntry(text);
    }

    _controller.clear();
    _focusNode.unfocus();
  }

  void _startEdit() {
    final entries =
        ref.read(entryListProvider(widget.topicId)).valueOrNull;
    if (entries == null || _selectedEntryId == null) return;

    final entry = entries.firstWhere((e) => e.id == _selectedEntryId);

    setState(() {
      _editingEntryId = _selectedEntryId;
      _selectedEntryId = null;
    });

    _controller.text = entry.content;
    _controller.selection =
        TextSelection.collapsed(offset: entry.content.length);
    _focusNode.requestFocus();
  }

  Future<void> _copyEntry() async {
    final entries =
        ref.read(entryListProvider(widget.topicId)).valueOrNull;
    if (entries == null || _selectedEntryId == null) return;

    final entry = entries.firstWhere((e) => e.id == _selectedEntryId);
    await Clipboard.setData(ClipboardData(text: entry.content));
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

    final entry = entries.firstWhere((e) => e.id == _selectedEntryId);
    _clearSelection();
    await Share.share(entry.content);
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
        // Editing takes priority — cancel edit first.
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
                      final entry = entries[index];
                      return EntryBubble(
                        entry: entry,
                        isSelected: entry.id == _selectedEntryId,
                        onLongPress: () {
                          // Cancel editing if active.
                          if (_editingEntryId != null) _cancelEdit();
                          setState(
                              () => _selectedEntryId = entry.id);
                        },
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
            ),
          ],
        ),
      ),
    );
  }
}
