import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

import 'topic_avatar.dart';

/// Bottom sheet for editing a topic's name and emoji icon.
///
/// Shows the current avatar (tappable to toggle the emoji picker), a text
/// field for the name, and action buttons (remove icon / save).
///
/// Returns a [TopicEditResult] via [Navigator.pop] when saved, or `null`
/// if cancelled.
class TopicEditSheet extends StatefulWidget {
  final String currentTitle;
  final String? currentIcon;

  const TopicEditSheet({
    super.key,
    required this.currentTitle,
    this.currentIcon,
  });

  @override
  State<TopicEditSheet> createState() => _TopicEditSheetState();
}

class _TopicEditSheetState extends State<TopicEditSheet> {
  late final TextEditingController _titleController;
  String? _selectedIcon;
  bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.currentTitle);
    _selectedIcon = widget.currentIcon;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _hasCustomIcon =>
      _selectedIcon != null && _selectedIcon!.isNotEmpty;

  bool get _hasChanges {
    final titleChanged = _titleController.text.trim() != widget.currentTitle;
    final iconChanged = _selectedIcon != widget.currentIcon;
    return titleChanged || iconChanged;
  }

  void _onEmojiSelected(Category? category, Emoji? emoji) {
    setState(() {
      if (emoji != null){
        _selectedIcon = emoji.emoji;
      }
      _showEmojiPicker = false;
    });
  }

  void _removeIcon() {
    setState(() {
      _selectedIcon = null;
      _showEmojiPicker = false;
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    Navigator.pop(
      context,
      TopicEditResult(title: title, icon: _selectedIcon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Avatar (tappable to toggle picker)
          GestureDetector(
            onTap: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                TopicAvatar(
                  title: _titleController.text.isNotEmpty
                      ? _titleController.text
                      : widget.currentTitle,
                  icon: _selectedIcon,
                  size: 64,
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _showEmojiPicker
                        ? Icons.keyboard_arrow_down
                        : Icons.emoji_emotions_outlined,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Title field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _titleController,
              autofocus: !_showEmojiPicker,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 100,
              decoration: const InputDecoration(
                hintText: 'Название топика',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
          ),
          const SizedBox(height: 12),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Remove icon button (visible only when a custom icon is set)
                if (_hasCustomIcon)
                  TextButton.icon(
                    onPressed: _removeIcon,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Убрать иконку'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed:
                      _titleController.text.trim().isNotEmpty && _hasChanges
                          ? _save
                          : null,
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Emoji picker (animated expand/collapse)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _showEmojiPicker
                ? SizedBox(
                    height: 256,
                    child: EmojiPicker(
                      onEmojiSelected: _onEmojiSelected,
                      config: Config(
                        height: 256,
                        checkPlatformCompatibility: true,
                        emojiViewConfig: EmojiViewConfig(
                          emojiSizeMax: 28 *
                              (foundation.defaultTargetPlatform ==
                                      TargetPlatform.iOS
                                  ? 1.20
                                  : 1.0),
                        ),
                        categoryViewConfig: const CategoryViewConfig(),
                        bottomActionBarConfig: const BottomActionBarConfig(
                          enabled: false,
                        ),
                        searchViewConfig: const SearchViewConfig(),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Result returned from [TopicEditSheet] when saved.
class TopicEditResult {
  final String title;
  final String? icon;

  const TopicEditResult({required this.title, this.icon});
}
