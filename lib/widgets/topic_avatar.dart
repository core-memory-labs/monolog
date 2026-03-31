import 'package:flutter/material.dart';

/// Reusable avatar widget for topics.
///
/// Displays either:
/// - A custom emoji icon (when [icon] is non-null), or
/// - A coloured circle with the first letter of [title] (default).
///
/// The circle colour is deterministic — derived from the title's hash code
/// using a fixed 10-colour palette.
class TopicAvatar extends StatelessWidget {
  /// Title of the topic (used for the fallback letter and colour).
  final String title;

  /// Custom emoji icon, or `null` for the default letter avatar.
  final String? icon;

  /// Diameter of the avatar circle / size of the emoji.
  final double size;

  const TopicAvatar({
    super.key,
    required this.title,
    this.icon,
    this.size = 40,
  });

  static const _palette = [
    Color(0xFFE57373), // red
    Color(0xFFFF8A65), // deep orange
    Color(0xFFFFB74D), // orange
    Color(0xFFFFD54F), // amber
    Color(0xFF81C784), // green
    Color(0xFF4DB6AC), // teal
    Color(0xFF4FC3F7), // light blue
    Color(0xFF7986CB), // indigo
    Color(0xFFBA68C8), // purple
    Color(0xFFA1887F), // brown
  ];

  @override
  Widget build(BuildContext context) {
    if (icon != null && icon!.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            icon!,
            style: TextStyle(fontSize: size * 0.7),
          ),
        ),
      );
    }

    final letter = title.isNotEmpty ? title[0].toUpperCase() : '?';
    final color = _palette[title.hashCode.abs() % _palette.length];

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
