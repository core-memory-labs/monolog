import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/database_service.dart';
import '../services/file_service.dart';
import '../services/link_preview_service.dart';
import '../services/sqlite_database_service.dart';
import '../services/local_file_service.dart';

/// Single instance of [DatabaseService] shared across the app.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final service = SqliteDatabaseService();
  ref.onDispose(() => service.close());
  return service;
});

/// Single instance of [FileService] shared across the app.
///
/// Handles saving and deleting attachment files (images and other files)
/// on disk. Renamed from `imageServiceProvider` in Stage 3.4.
final fileServiceProvider = Provider<FileService>((ref) {
  return LocalFileService();
});

/// Single instance of [LinkPreviewService] shared across the app.
///
/// Fetches, parses, and caches OpenGraph link previews. Uses
/// [DatabaseService] for persistent cache and downloads OG images to disk.
final linkPreviewServiceProvider = Provider<LinkPreviewService>((ref) {
  return LinkPreviewService(
    db: ref.read(databaseServiceProvider),
  );
});

/// [SharedPreferences] instance, eagerly initialised in `main.dart` and
/// injected via `ProviderContainer.overrides`.
///
/// Used by [ThemeNotifier] (and potentially future settings) to persist
/// user preferences across app restarts.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  // This provider is always overridden in main.dart with an actual instance.
  // If accessed without override, something is wrong.
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with a real instance',
  );
});
