import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/database/tables/transactions.dart';
import '../../core/utils/date_formatter.dart';
import '../repositories/budget_repository.dart';

enum BudgetStatus {
  underBudget,
  nearLimit,
  overBudget,
}

class BudgetSummary {
  final String period;
  final double budget;
  final double spending;

  const BudgetSummary({
    required this.period,
    required this.budget,
    required this.spending,
  });

  double get remaining => budget - spending;

  double get overrun => spending > budget ? spending - budget : 0.0;

  double get usagePercentage => budget > 0 ? (spending / budget) * 100 : 0.0;

  double get visualProgress =>
      budget > 0 ? (spending / budget).clamp(0.0, 1.0) : 0.0;

  BudgetStatus get status {
    final usage = usagePercentage;
    if (usage < 80.0) {
      return BudgetStatus.underBudget;
    } else if (usage < 100.0) {
      return BudgetStatus.nearLimit;
    } else {
      return BudgetStatus.overBudget;
    }
  }

  String get statusLabel {
    switch (status) {
      case BudgetStatus.underBudget:
        return 'UNDER BUDGET';
      case BudgetStatus.nearLimit:
        return 'NEAR LIMIT';
      case BudgetStatus.overBudget:
        return 'OVER BUDGET';
    }
  }
}

abstract class BudgetService {
  Future<BudgetSummary> getMonthlyBudgetSummary({DateTime? date});

  Future<void> setMonthlyBudget({required double amount, DateTime? date});

  Future<double> getMonthlyExpenseTotal({required DateTime month});
}

class DriftBudgetService implements BudgetService {
  final AppDatabase _db;
  final BudgetRepository _budgetRepository;

  static const double defaultMonthlyBudget = 9000.0;

  DriftBudgetService(this._db, [BudgetRepository? budgetRepository])
      : _budgetRepository = budgetRepository ?? DriftBudgetRepository(_db);

  @override
  Future<BudgetSummary> getMonthlyBudgetSummary({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final period = DateFormatter.toPeriod(targetDate);

    final existingBudget = await _budgetRepository.getBudgetForPeriod(period);
    final budgetAmount = existingBudget?.amount ?? defaultMonthlyBudget;

    // Persist default budget if none existed yet for this period
    if (existingBudget == null) {
      await _budgetRepository.setBudget(period: period, amount: budgetAmount);
    }

    final spending = await getMonthlyExpenseTotal(month: targetDate);

    return BudgetSummary(
      period: period,
      budget: budgetAmount,
      spending: spending,
    );
  }

  @override
  Future<void> setMonthlyBudget({
    required double amount,
    DateTime? date,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Budget amount must be greater than zero');
    }
    final targetDate = date ?? DateTime.now();
    final period = DateFormatter.toPeriod(targetDate);
    await _budgetRepository.setBudget(period: period, amount: amount);
  }

  @override
  Future<double> getMonthlyExpenseTotal({required DateTime month}) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final startOfNextMonth = DateTime(month.year, month.month + 1, 1);

    final expenses = await (_db.select(_db.transactions)
          ..where((tbl) =>
              tbl.type.equalsValue(TransactionType.expense) &
              tbl.transactionDate.isBiggerOrEqualValue(startOfMonth) &
              tbl.transactionDate.isSmallerThanValue(startOfNextMonth)))
        .get();

    return expenses.fold<double>(0.0, (sum, tx) => sum + tx.amount);
  }
}
