import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/entry_list_notifier.dart';
import '../utils/dialogs.dart';

/// Fullscreen image viewer with zoom/pan support.
///
/// AppBar: ← back (left), ⋮ menu (right) with "Поделиться",
/// "Сохранить в галерею", and "Удалить".
/// Deleting removes the entire entry (image + text) after confirmation.
class ImageViewerScreen extends ConsumerWidget {
  final String imagePath;
  final int entryId;
  final int topicId;

  const ImageViewerScreen({
    super.key,
    required this.imagePath,
    required this.entryId,
    required this.topicId,
  });

  Future<void> _shareImage() async {
    await Share.shareXFiles([XFile(imagePath)]);
  }

  Future<void> _saveToGallery(BuildContext context) async {
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Нет доступа к галерее'),
              ),
            );
          }
          return;
        }
      }
      await Gal.putImage(imagePath);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сохранено в галерею'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    }
  }

  Future<void> _deleteEntry(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDeleteConfirmation(
      context,
      title: 'Удалить запись?',
      message: 'Запись и изображение будут удалены безвозвратно.',
    );

    if (confirmed == true) {
      await ref
          .read(entryListProvider(topicId).notifier)
          .deleteEntry(entryId);
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<_ViewerAction>(
            onSelected: (action) {
              switch (action) {
                case _ViewerAction.share:
                  _shareImage();
                case _ViewerAction.saveToGallery:
                  _saveToGallery(context);
                case _ViewerAction.delete:
                  _deleteEntry(context, ref);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ViewerAction.share,
                child: Text('Поделиться'),
              ),
              PopupMenuItem(
                value: _ViewerAction.saveToGallery,
                child: Text('Сохранить в галерею'),
              ),
              PopupMenuItem(
                value: _ViewerAction.delete,
                child: Text('Удалить запись'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: 'entry_image_$entryId',
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.file(
              File(imagePath),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ViewerAction { share, saveToGallery, delete }
