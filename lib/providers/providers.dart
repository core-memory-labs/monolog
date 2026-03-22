import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/database_service.dart';
import '../services/file_service.dart';

/// Single instance of [DatabaseService] shared across the app.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final service = DatabaseService();
  ref.onDispose(() => service.close());
  return service;
});

/// Single instance of [FileService] shared across the app.
///
/// Handles saving and deleting attachment files (images and other files)
/// on disk. Renamed from `imageServiceProvider` in Stage 3.4.
final fileServiceProvider = Provider<FileService>((ref) {
  return FileService();
});
