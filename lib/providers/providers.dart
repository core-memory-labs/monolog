import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/database_service.dart';
import '../services/image_service.dart';

/// Single instance of [DatabaseService] shared across the app.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final service = DatabaseService();
  ref.onDispose(() => service.close());
  return service;
});

/// Single instance of [ImageService] shared across the app.
final imageServiceProvider = Provider<ImageService>((ref) {
  return ImageService();
});
