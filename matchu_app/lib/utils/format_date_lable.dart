String formatDateLabel(DateTime date) {
  final now = DateTime.now();

  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final d = DateTime(date.year, date.month, date.day);

  if (d == today) return "Hôm nay";
  if (d == yesterday) return "Hôm qua";

  return "${d.day.toString().padLeft(2, '0')}/"
         "${d.month.toString().padLeft(2, '0')}/"
         "${d.year}";
}
