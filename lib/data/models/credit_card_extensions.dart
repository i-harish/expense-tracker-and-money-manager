import '../../core/database/app_database.dart';

extension CreditCardExtension on CreditCard {
  /// Calculates available credit: creditLimit - outstandingBalance (clamped to >= 0)
  double get availableCredit =>
      (creditLimit - outstandingBalance).clamp(0.0, double.infinity);

  /// Calculates credit utilization percentage: (outstandingBalance / creditLimit) * 100
  double get utilizationPercentage =>
      creditLimit > 0 ? (outstandingBalance / creditLimit) * 100 : 0.0;
}
