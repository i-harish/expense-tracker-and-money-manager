import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_and_money_manager/core/database/app_database.dart';
import 'package:expense_tracker_and_money_manager/core/database/tables/accounts.dart';
import 'package:expense_tracker_and_money_manager/data/repositories/account_repository.dart';
import 'package:expense_tracker_and_money_manager/data/repositories/budget_repository.dart';
import 'package:expense_tracker_and_money_manager/data/services/budget_service.dart';
import 'package:expense_tracker_and_money_manager/data/services/financial_service.dart';

void main() {
  late AppDatabase database;
  late AccountRepository accountRepository;
  late BudgetRepository budgetRepository;
  late FinancialService financialService;
  late BudgetService budgetService;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    accountRepository = DriftAccountRepository(database);
    budgetRepository = DriftBudgetRepository(database);
    financialService = DriftFinancialService(database);
    budgetService = DriftBudgetService(database, budgetRepository);
  });

  tearDown(() async {
    await database.close();
  });

  group('Milestone 5: Budget Service Tests', () {
    test('Test 1 — Monthly expense calculation filters by calendar month',
        () async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 50000.0,
      );

      // September 2026 expenses
      await financialService.recordExpense(
        accountId: accountId,
        amount: 1000.0,
        transactionDate: DateTime(2026, 9, 5),
      );
      await financialService.recordExpense(
        accountId: accountId,
        amount: 2000.0,
        transactionDate: DateTime(2026, 9, 15),
      );
      await financialService.recordExpense(
        accountId: accountId,
        amount: 3000.0,
        transactionDate: DateTime(2026, 9, 28),
      );

      // August 2026 expense (should not be included)
      await financialService.recordExpense(
        accountId: accountId,
        amount: 5000.0,
        transactionDate: DateTime(2026, 8, 20),
      );

      final sepSpending = await budgetService.getMonthlyExpenseTotal(
        month: DateTime(2026, 9, 1),
      );

      expect(sepSpending, equals(6000.0));
    });

    test('Test 2 — Under budget calculation and status', () async {
      const summary = BudgetSummary(
        period: '2026-09',
        budget: 9000.0,
        spending: 5000.0,
      );

      expect(summary.remaining, equals(4000.0));
      expect(summary.overrun, equals(0.0));
      expect(double.parse(summary.usagePercentage.toStringAsFixed(2)),
          equals(55.56));
      expect(summary.status, equals(BudgetStatus.underBudget));
    });

    test('Test 3 — Near limit calculation and status', () async {
      const summary = BudgetSummary(
        period: '2026-09',
        budget: 9000.0,
        spending: 8000.0,
      );

      expect(summary.remaining, equals(1000.0));
      expect(summary.overrun, equals(0.0));
      expect(double.parse(summary.usagePercentage.toStringAsFixed(2)),
          equals(88.89));
      expect(summary.status, equals(BudgetStatus.nearLimit));
    });

    test('Test 4 — Exactly at budget calculation and status', () async {
      const summary = BudgetSummary(
        period: '2026-09',
        budget: 9000.0,
        spending: 9000.0,
      );

      expect(summary.remaining, equals(0.0));
      expect(summary.overrun, equals(0.0));
      expect(summary.usagePercentage, equals(100.0));
      expect(summary.status, equals(BudgetStatus.overBudget));
    });

    test('Test 5 — Over budget calculation, overrun, and status', () async {
      const summary = BudgetSummary(
        period: '2026-09',
        budget: 9000.0,
        spending: 9500.0,
      );

      expect(summary.remaining, equals(-500.0));
      expect(summary.overrun, equals(500.0));
      expect(double.parse(summary.usagePercentage.toStringAsFixed(2)),
          equals(105.56));
      expect(summary.status, equals(BudgetStatus.overBudget));
    });

    test('Test 6 — Budget update persists and leaves transactions intact',
        () async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 20000.0,
      );

      await financialService.recordExpense(
        accountId: accountId,
        amount: 2500.0,
        transactionDate: DateTime(2026, 9, 10),
      );

      await budgetService.setMonthlyBudget(
        amount: 9000.0,
        date: DateTime(2026, 9, 1),
      );

      var summary = await budgetService.getMonthlyBudgetSummary(
        date: DateTime(2026, 9, 1),
      );
      expect(summary.budget, equals(9000.0));
      expect(summary.spending, equals(2500.0));

      // Update budget
      await budgetService.setMonthlyBudget(
        amount: 10000.0,
        date: DateTime(2026, 9, 1),
      );

      summary = await budgetService.getMonthlyBudgetSummary(
        date: DateTime(2026, 9, 1),
      );
      expect(summary.budget, equals(10000.0));
      expect(summary.spending, equals(2500.0)); // Spending unchanged
    });

    test('Test 7 — New month creates fresh period with zero initial spending',
        () async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 20000.0,
      );

      // September spending
      await financialService.recordExpense(
        accountId: accountId,
        amount: 8000.0,
        transactionDate: DateTime(2026, 9, 15),
      );

      final sepSummary = await budgetService.getMonthlyBudgetSummary(
        date: DateTime(2026, 9, 1),
      );
      expect(sepSummary.spending, equals(8000.0));

      // October query
      final octSummary = await budgetService.getMonthlyBudgetSummary(
        date: DateTime(2026, 10, 1),
      );
      expect(octSummary.spending, equals(0.0));
      expect(octSummary.budget, equals(9000.0)); // Default budget applied
    });

    test('Test 8 — Historical transaction preservation when over budget',
        () async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 20000.0,
      );

      await financialService.recordExpense(
        accountId: accountId,
        amount: 9500.0,
        description: 'Big Purchase',
        transactionDate: DateTime(2026, 9, 12),
      );

      final summary = await budgetService.getMonthlyBudgetSummary(
        date: DateTime(2026, 9, 1),
      );

      expect(summary.spending, equals(9500.0));
      expect(summary.budget, equals(9000.0));
      expect(summary.overrun, equals(500.0));

      final allTx = await financialService.getTransactionsWithAccount();
      expect(allTx.first.transaction.amount, equals(9500.0));
    });
  });
}
