import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_and_money_manager/core/database/app_database.dart';
import 'package:expense_tracker_and_money_manager/core/database/tables/accounts.dart';
import 'package:expense_tracker_and_money_manager/core/database/tables/transactions.dart';
import 'package:expense_tracker_and_money_manager/data/repositories/account_repository.dart';
import 'package:expense_tracker_and_money_manager/data/services/financial_service.dart';

void main() {
  late AppDatabase database;
  late AccountRepository accountRepository;
  late FinancialService financialService;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    accountRepository = DriftAccountRepository(database);
    financialService = DriftFinancialService(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Milestone 4: Financial Service & Transaction Tests', () {
    test('Test 1 — Record income increases balance and creates transaction',
        () async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 10000.0,
      );

      final transactionId = await financialService.recordIncome(
        accountId: accountId,
        amount: 42000.0,
        description: 'Salary',
      );

      final updatedAccount = await accountRepository.getAccountById(accountId);
      expect(updatedAccount, isNotNull);
      expect(updatedAccount!.balance, equals(52000.0));

      final transactions =
          await financialService.getTransactionsWithAccount();
      expect(transactions.length, equals(1));
      expect(transactions.first.transaction.id, equals(transactionId));
      expect(transactions.first.transaction.amount, equals(42000.0));
      expect(transactions.first.transaction.type,
          equals(TransactionType.income));
      expect(transactions.first.transaction.description, equals('Salary'));
      expect(transactions.first.account!.id, equals(accountId));
    });

    test('Test 2 — Record expense decreases balance and creates transaction',
        () async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 10000.0,
      );

      final transactionId = await financialService.recordExpense(
        accountId: accountId,
        amount: 1500.0,
        description: 'Groceries',
      );

      final updatedAccount = await accountRepository.getAccountById(accountId);
      expect(updatedAccount, isNotNull);
      expect(updatedAccount!.balance, equals(8500.0));

      final transactions =
          await financialService.getTransactionsWithAccount();
      expect(transactions.length, equals(1));
      expect(transactions.first.transaction.id, equals(transactionId));
      expect(transactions.first.transaction.amount, equals(1500.0));
      expect(transactions.first.transaction.type,
          equals(TransactionType.expense));
      expect(transactions.first.transaction.description, equals('Groceries'));
    });

    test('Test 3 — Multiple transactions update balance in sequence', () async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 10000.0,
      );

      await financialService.recordIncome(
        accountId: accountId,
        amount: 5000.0,
      );
      await financialService.recordExpense(
        accountId: accountId,
        amount: 2000.0,
      );
      await financialService.recordExpense(
        accountId: accountId,
        amount: 500.0,
      );

      final updatedAccount = await accountRepository.getAccountById(accountId);
      expect(updatedAccount, isNotNull);
      expect(updatedAccount!.balance, equals(12500.0));

      final transactions =
          await financialService.getTransactionsWithAccount();
      expect(transactions.length, equals(3));
    });

    test('Test 4 — Insufficient balance rejects expense and preserves state',
        () async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 500.0,
      );

      expect(
        () => financialService.recordExpense(
          accountId: accountId,
          amount: 600.0,
        ),
        throwsA(isA<InsufficientBalanceException>()),
      );

      final account = await accountRepository.getAccountById(accountId);
      expect(account, isNotNull);
      expect(account!.balance, equals(500.0)); // Balance unchanged

      final transactions =
          await financialService.getTransactionsWithAccount();
      expect(transactions, isEmpty); // No transaction created
    });

    test('Test 5 — Zero amount fails validation', () async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 1000.0,
      );

      expect(
        () => financialService.recordExpense(
          accountId: accountId,
          amount: 0.0,
        ),
        throwsA(isA<InvalidTransactionException>()),
      );

      final account = await accountRepository.getAccountById(accountId);
      expect(account!.balance, equals(1000.0));

      final transactions =
          await financialService.getTransactionsWithAccount();
      expect(transactions, isEmpty);
    });

    test('Test 6 — Negative amount fails validation', () async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 1000.0,
      );

      expect(
        () => financialService.recordIncome(
          accountId: accountId,
          amount: -500.0,
        ),
        throwsA(isA<InvalidTransactionException>()),
      );

      final account = await accountRepository.getAccountById(accountId);
      expect(account!.balance, equals(1000.0));

      final transactions =
          await financialService.getTransactionsWithAccount();
      expect(transactions, isEmpty);
    });

    test('Test 7 — Transaction on inactive account is rejected', () async {
      final accountId = await accountRepository.createAccount(
        name: 'Old Bank',
        type: AccountType.bank,
        balance: 1000.0,
      );

      await accountRepository.deactivateAccount(accountId);

      expect(
        () => financialService.recordIncome(
          accountId: accountId,
          amount: 500.0,
        ),
        throwsA(isA<InactiveAccountException>()),
      );

      expect(
        () => financialService.recordExpense(
          accountId: accountId,
          amount: 200.0,
        ),
        throwsA(isA<InactiveAccountException>()),
      );

      final account = await accountRepository.getAccountById(accountId);
      expect(account!.balance, equals(1000.0));

      final transactions =
          await financialService.getTransactionsWithAccount();
      expect(transactions, isEmpty);
    });

    test('Test 8 — Atomicity ensures consistent rollback on failure', () async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 100.0,
      );

      // Attempt expense exceeding balance
      try {
        await financialService.recordExpense(
          accountId: accountId,
          amount: 500.0,
        );
      } catch (_) {}

      // Both balance and transactions table must be untampered
      final account = await accountRepository.getAccountById(accountId);
      expect(account!.balance, equals(100.0));

      final transactions =
          await financialService.getTransactionsWithAccount();
      expect(transactions, isEmpty);
    });
  });
}
