import 'package:flutter/material.dart';

import 'screens/topic_list_screen.dart';

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
      home: const TopicListScreen(),
    );
  }
}
