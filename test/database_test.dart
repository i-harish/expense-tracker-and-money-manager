import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_and_money_manager/core/database/app_database.dart';
import 'package:expense_tracker_and_money_manager/core/database/tables/accounts.dart';
import 'package:expense_tracker_and_money_manager/core/database/tables/transactions.dart';
import 'package:expense_tracker_and_money_manager/data/repositories/account_repository.dart';
import 'package:expense_tracker_and_money_manager/data/repositories/budget_repository.dart';
import 'package:expense_tracker_and_money_manager/data/repositories/transaction_repository.dart';

void main() {
  late AppDatabase database;
  late AccountRepository accountRepository;
  late TransactionRepository transactionRepository;
  late BudgetRepository budgetRepository;

  setUp(() {
    // In-memory database for isolated, fast, and repeatable testing
    database = AppDatabase.forTesting(NativeDatabase.memory());
    accountRepository = DriftAccountRepository(database);
    transactionRepository = DriftTransactionRepository(database);
    budgetRepository = DriftBudgetRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Milestone 2: Local Database Tests', () {
    test('Test 1 — Database initialization', () async {
      expect(database.schemaVersion, equals(1));
      final accounts = await database.select(database.accounts).get();
      expect(accounts, isEmpty);
      final transactions = await database.select(database.transactions).get();
      expect(transactions, isEmpty);
      final budgets = await database.select(database.budgets).get();
      expect(budgets, isEmpty);
    });

    test('Test 2 — Account insertion', () async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 10000.0,
        currency: 'INR',
      );

      final account = await accountRepository.getAccountById(accountId);

      expect(account, isNotNull);
      expect(account!.id, equals(accountId));
      expect(account.name, equals('Main Bank'));
      expect(account.type, equals(AccountType.bank));
      expect(account.balance, equals(10000.0));
      expect(account.currency, equals('INR'));
      expect(account.isActive, isTrue);
      expect(account.createdAt, isNotNull);
      expect(account.updatedAt, isNotNull);
    });

    test('Test 3 — Multiple accounts', () async {
      await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 10000.0,
      );
      await accountRepository.createAccount(
        name: 'Savings',
        type: AccountType.savings,
        balance: 50000.0,
      );
      await accountRepository.createAccount(
        name: 'Cash',
        type: AccountType.cash,
        balance: 2000.0,
      );

      final allAccounts = await accountRepository.getAllAccounts();

      expect(allAccounts.length, equals(3));
      final names = allAccounts.map((a) => a.name).toList();
      expect(names, containsAll(['Main Bank', 'Savings', 'Cash']));

      final types = allAccounts.map((a) => a.type).toList();
      expect(
        types,
        containsAll([AccountType.bank, AccountType.savings, AccountType.cash]),
      );
    });

    test('Test 4 — Transaction insertion', () async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 10000.0,
      );

      final now = DateTime.now();
      final transactionId = await transactionRepository.createTransaction(
        accountId: accountId,
        type: TransactionType.expense,
        amount: 450.0,
        description: 'Grocery shopping',
        transactionDate: now,
      );

      final transaction =
          await transactionRepository.getTransactionById(transactionId);

      expect(transaction, isNotNull);
      expect(transaction!.id, equals(transactionId));
      expect(transaction.accountId, equals(accountId));
      expect(transaction.type, equals(TransactionType.expense));
      expect(transaction.amount, equals(450.0));
      expect(transaction.description, equals('Grocery shopping'));
      expect(
        (transaction.transactionDate.millisecondsSinceEpoch ~/ 1000),
        equals(now.millisecondsSinceEpoch ~/ 1000),
      );

      final accountTransactions =
          await transactionRepository.getTransactionsByAccountId(accountId);
      expect(accountTransactions.length, equals(1));
      expect(accountTransactions.first.id, equals(transactionId));
    });

    test('Test 5 — Budget insertion', () async {
      const period = '2026-09';
      const budgetAmount = 9000.0;

      final budgetId = await budgetRepository.setBudget(
        period: period,
        amount: budgetAmount,
      );

      final budget = await budgetRepository.getBudgetForPeriod(period);

      expect(budget, isNotNull);
      expect(budget!.id, equals(budgetId));
      expect(budget.period, equals(period));
      expect(budget.amount, equals(9000.0));
      expect(budget.createdAt, isNotNull);
      expect(budget.updatedAt, isNotNull);

      // Verify updating existing budget for the same period
      final updatedId = await budgetRepository.setBudget(
        period: period,
        amount: 12000.0,
      );

      expect(updatedId, equals(budgetId));
      final updatedBudget = await budgetRepository.getBudgetForPeriod(period);
      expect(updatedBudget, isNotNull);
      expect(updatedBudget!.amount, equals(12000.0));
    });
  });
}
