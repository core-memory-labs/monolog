import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_service.dart';

/// Single instance of [DatabaseService] shared across the app.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final service = DatabaseService();
  ref.onDispose(() => service.close());
  return service;
});
