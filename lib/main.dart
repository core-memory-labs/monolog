import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Eagerly initialise the database so tables are created on first launch.
  final container = ProviderContainer();
  await container.read(databaseServiceProvider).database;

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MonologApp(),
    ),
  );
}
