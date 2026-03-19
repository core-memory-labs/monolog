import 'package:flutter/material.dart';

class MonologApp extends StatelessWidget {
  const MonologApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monolog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const _PlaceholderHome(),
    );
  }
}

/// Temporary home screen — will be replaced in Stage 2 with TopicListScreen.
class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monolog')),
      body: const Center(
        child: Text('Каркас готов. Следующий шаг — экран топиков.'),
      ),
    );
  }
}
