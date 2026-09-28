import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

abstract class BudgetRepository {
  Future<int> setBudget({
    required String period,
    required double amount,
  });

  Future<Budget?> getBudgetForPeriod(String period);

  Future<List<Budget>> getAllBudgets();

  Future<int> deleteBudget(int id);
}

class DriftBudgetRepository implements BudgetRepository {
  final AppDatabase _db;

  DriftBudgetRepository(this._db);

  @override
  Future<int> setBudget({
    required String period,
    required double amount,
  }) async {
    final now = DateTime.now();
    final existing = await getBudgetForPeriod(period);

    if (existing != null) {
      await (_db.update(_db.budgets)..where((tbl) => tbl.id.equals(existing.id)))
          .write(
        BudgetsCompanion(
          amount: Value(amount),
          updatedAt: Value(now),
        ),
      );
      return existing.id;
    } else {
      return _db.into(_db.budgets).insert(
            BudgetsCompanion.insert(
              period: period,
              amount: Value(amount),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }
  }

  @override
  Future<Budget?> getBudgetForPeriod(String period) async {
    return (_db.select(_db.budgets)..where((tbl) => tbl.period.equals(period)))
        .getSingleOrNull();
  }

  @override
  Future<List<Budget>> getAllBudgets() async {
    return (_db.select(_db.budgets)
          ..orderBy([
            (tbl) => OrderingTerm(
                  expression: tbl.period,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  @override
  Future<int> deleteBudget(int id) async {
    return (_db.delete(_db.budgets)..where((tbl) => tbl.id.equals(id))).go();
  }
}
