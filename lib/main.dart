import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import './providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait only.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Use FFI-based SQLite with FTS5 support.
  // System SQLite on Android (especially API 21–24) does not include FTS5.
  // sqlite3_flutter_libs provides a full SQLite build with FTS5 enabled.
  await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Load SharedPreferences for theme and future settings.
  final prefs = await SharedPreferences.getInstance();

  // Eagerly initialise the database so tables are created on first launch.
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  await container.read(databaseServiceProvider).database;

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MonologApp(),
    ),
  );
}
