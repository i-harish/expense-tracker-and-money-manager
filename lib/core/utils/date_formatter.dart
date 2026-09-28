class DateFormatter {
  DateFormatter._();

  static const List<String> _shortMonths = [
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

  static const List<String> _fullMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Formats date to 'dd MMM yyyy' (e.g. '28 Sep 2026')
  static String format(DateTime date) {
    final day = date.day;
    final month = _shortMonths[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  /// Formats date to period string 'yyyy-MM' (e.g. '2026-09')
  static String toPeriod(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    return '$year-$month';
  }

  /// Formats date to 'MMMM yyyy' (e.g. 'September 2026')
  static String formatMonthYear(DateTime date) {
    final month = _fullMonths[date.month - 1];
    final year = date.year;
    return '$month $year';
  }
}
