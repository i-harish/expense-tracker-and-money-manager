class DateFormatter {
  DateFormatter._();

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Formats date to 'dd MMM yyyy' (e.g. '28 Sep 2026')
  static String format(DateTime date) {
    final day = date.day;
    final month = _months[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }
}
