import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/topic_list_notifier.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/file_service.dart';
import '../services/telegram_import_service.dart';
import '../providers/providers.dart';

/// Settings screen with export and import options.
///
/// Accessible via the ⚙️ icon in the topic list AppBar.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;
  bool _isImporting = false;

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<void> _exportData() async {
    if (_isExporting) return;

    setState(() => _isExporting = true);

    try {
      final db = ref.read(databaseServiceProvider);
      final exportService = ExportService(db: db);
      final result = await exportService.export();

      if (!mounted) return;

      // Share the ZIP file.
      await Share.shareXFiles(
        [XFile(result.zipPath)],
        subject: 'Monolog — резервная копия',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Экспортировано: ${result.topicCount} топиков, '
            '${result.entryCount} записей, '
            '${result.fileCount} файлов',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка экспорта: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Telegram import
  // ---------------------------------------------------------------------------

  Future<void> _importFromTelegram() async {
    if (_isImporting) return;

    // Pick ZIP file.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;

    setState(() => _isImporting = true);

    try {
      final db = ref.read(databaseServiceProvider);
      final fileService = ref.read(fileServiceProvider);
      final importService = TelegramImportService(
        db: db,
        fileService: fileService,
      );

      final importResult = await importService.importFromZip(filePath);

      if (!mounted) return;

      // Refresh topic list.
      ref.invalidate(topicListProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Импортировано: ${importResult.topicCount} топиков, '
            '${importResult.entryCount} записей, '
            '${importResult.fileCount} файлов',
          ),
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка импорта: $e')),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          const _SectionHeader('Данные'),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Экспорт данных'),
            subtitle: const Text('Сохранить все данные в ZIP-архив'),
            trailing: _isExporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            enabled: !_isExporting && !_isImporting,
            onTap: _exportData,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Импорт из Telegram'),
            subtitle: const Text('Загрузить ZIP-экспорт чата с топиками'),
            trailing: _isImporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            enabled: !_isExporting && !_isImporting,
            onTap: _importFromTelegram,
          ),
          const Divider(),
          const _SectionHeader('О приложении'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Monolog'),
            subtitle: Text('Версия 1.0.0 · Приватный блокнот'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
