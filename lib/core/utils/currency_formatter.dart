class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formats a numerical amount into Indian currency format (e.g. ₹25,000 or ₹1,50,000).
  static String format(double amount, {String currency = 'INR'}) {
    final symbol = currency == 'INR' ? '₹' : '$currency ';
    final isNegative = amount < 0;
    final absAmount = amount.abs();

    final hasDecimal = absAmount % 1 != 0;
    final parts = (hasDecimal
            ? absAmount.toStringAsFixed(2)
            : absAmount.toStringAsFixed(0))
        .split('.');

    String integerPart = parts[0];
    final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';

    if (integerPart.length > 3) {
      final lastThree = integerPart.substring(integerPart.length - 3);
      var remaining = integerPart.substring(0, integerPart.length - 3);
      final chunks = <String>[];
      while (remaining.length > 2) {
        chunks.insert(0, remaining.substring(remaining.length - 2));
        remaining = remaining.substring(0, remaining.length - 2);
      }
      if (remaining.isNotEmpty) {
        chunks.insert(0, remaining);
      }
      integerPart = '${chunks.join(',')},$lastThree';
    }

    return '${isNegative ? '-' : ''}$symbol$integerPart$decimalPart';
  }
}
