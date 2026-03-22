/// Formats a [DateTime] as a human-readable relative or short date string.
///
/// Returns "Сегодня", "Вчера", or "dd.MM.yyyy".
/// Used by topic list tiles.
String formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dateOnly = DateTime(date.year, date.month, date.day);

  if (dateOnly == today) return 'Сегодня';
  if (dateOnly == today.subtract(const Duration(days: 1))) return 'Вчера';

  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d.$m.${date.year}';
}

/// Formats a [DateTime] for display in the entry feed.
///
/// Returns "HH:mm" for today, "Вчера, HH:mm" for yesterday,
/// or "dd.MM.yyyy HH:mm" for older dates.
String formatEntryDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dateOnly = DateTime(date.year, date.month, date.day);

  final h = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  final time = '$h:$min';

  if (dateOnly == today) return time;
  if (dateOnly == today.subtract(const Duration(days: 1))) {
    return 'Вчера, $time';
  }

  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d.$m.${date.year} $time';
}
