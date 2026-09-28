import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_and_money_manager/core/database/app_database.dart';
import 'package:expense_tracker_and_money_manager/core/database/tables/accounts.dart';
import 'package:expense_tracker_and_money_manager/data/repositories/account_repository.dart';

void main() {
  late AppDatabase database;
  late AccountRepository accountRepository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    accountRepository = DriftAccountRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Milestone 3: Account Management Tests', () {
    test('Test 1 — Create account persists correctly', () async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 10000.0,
        currency: 'INR',
      );

      final account = await accountRepository.getAccountById(accountId);
      expect(account, isNotNull);
      expect(account!.name, equals('Main Bank'));
      expect(account.type, equals(AccountType.bank));
      expect(account.balance, equals(10000.0));
      expect(account.currency, equals('INR'));
      expect(account.isActive, isTrue);
    });

    test('Test 2 — Retrieve active accounts', () async {
      await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 25000.0,
      );
      await accountRepository.createAccount(
        name: 'Savings Account',
        type: AccountType.savings,
        balance: 50000.0,
      );
      await accountRepository.createAccount(
        name: 'Cash Wallet',
        type: AccountType.cash,
        balance: 2000.0,
      );

      final activeAccounts = await accountRepository.getActiveAccounts();
      expect(activeAccounts.length, equals(3));
      expect(activeAccounts.map((a) => a.name),
          containsAll(['Main Bank', 'Savings Account', 'Cash Wallet']));
    });

    test(
        'Test 3 — Edit account updates name and type but retains balance',
        () async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 25000.0,
      );

      final success = await accountRepository.updateAccountDetails(
        id: accountId,
        name: 'Primary Bank',
        type: AccountType.bank,
      );

      expect(success, isTrue);
      final updated = await accountRepository.getAccountById(accountId);
      expect(updated, isNotNull);
      expect(updated!.name, equals('Primary Bank'));
      expect(updated.type, equals(AccountType.bank));
      expect(updated.balance, equals(25000.0));
    });

    test(
        'Test 4 — Deactivate account hides from active list but retains record',
        () async {
      final accountId = await accountRepository.createAccount(
        name: 'Cash',
        type: AccountType.cash,
        balance: 2000.0,
      );

      final deactivated =
          await accountRepository.deactivateAccount(accountId);
      expect(deactivated, isTrue);

      final activeAccounts = await accountRepository.getActiveAccounts();
      expect(activeAccounts.where((a) => a.id == accountId), isEmpty);

      final rawAccount = await accountRepository.getAccountById(accountId);
      expect(rawAccount, isNotNull);
      expect(rawAccount!.id, equals(accountId));
      expect(rawAccount.isActive, isFalse);
    });

    test('Test 5 — Validation rejects invalid account data', () async {
      // Empty name
      expect(
        () => accountRepository.createAccount(
          name: '',
          type: AccountType.bank,
          balance: 1000.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Blank whitespace name
      expect(
        () => accountRepository.createAccount(
          name: '   ',
          type: AccountType.bank,
          balance: 1000.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Negative opening balance
      expect(
        () => accountRepository.createAccount(
          name: 'Main Bank',
          type: AccountType.bank,
          balance: -500.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
