// ignore_for_file: depend_on_referenced_packages
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:expense_tracker_and_money_manager/core/database/app_database.dart';
import 'package:expense_tracker_and_money_manager/core/database/tables/transactions.dart';

void main() {
  test(
      'Migration from schema version 2 to 3 preserves data and updates transactions schema',
      () async {
    final rawSqliteDb = sqlite3.openInMemory();

    // 1. Manually set up schema version 2 in sqlite3
    rawSqliteDb.execute('''
      CREATE TABLE accounts (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0.0,
        currency TEXT NOT NULL DEFAULT 'INR',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        transaction_date INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE budgets (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        period TEXT NOT NULL UNIQUE,
        amount REAL NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE credit_cards (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        last_four_digits TEXT NOT NULL,
        credit_limit REAL NOT NULL,
        outstanding_balance REAL NOT NULL DEFAULT 0.0,
        billing_cycle_day INTEGER,
        payment_due_day INTEGER,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    rawSqliteDb.execute('''
      INSERT INTO accounts (id, name, type, balance, currency, is_active, created_at, updated_at)
      VALUES (1, 'Main Bank', 'bank', 10000.0, 'INR', 1, $now, $now);

      INSERT INTO credit_cards (id, name, last_four_digits, credit_limit, outstanding_balance, is_active, created_at, updated_at)
      VALUES (1, 'HDFC Millennia', '1234', 100000.0, 5000.0, 1, $now, $now);

      INSERT INTO transactions (id, account_id, type, amount, description, transaction_date, created_at, updated_at)
      VALUES (1, 1, 'expense', 500.0, 'Coffee', $now, $now, $now);

      PRAGMA user_version = 2;
    ''');

    // 2. Open with AppDatabase (which runs onUpgrade from 2 to 3)
    final upgradedDb = AppDatabase.forTesting(NativeDatabase.opened(rawSqliteDb));

    // Perform operations to trigger migration
    final accounts = await upgradedDb.select(upgradedDb.accounts).get();
    expect(accounts.length, equals(1));
    expect(accounts.first.name, equals('Main Bank'));

    final cards = await upgradedDb.select(upgradedDb.creditCards).get();
    expect(cards.length, equals(1));
    expect(cards.first.name, equals('HDFC Millennia'));

    final txs = await upgradedDb.select(upgradedDb.transactions).get();
    expect(txs.length, equals(1));
    expect(txs.first.description, equals('Coffee'));
    expect(txs.first.accountId, equals(1));
    expect(txs.first.creditCardId, isNull);

    // Test inserting credit card purchase (null accountId, valid creditCardId)
    await upgradedDb.into(upgradedDb.transactions).insert(
          TransactionsCompanion.insert(
            creditCardId: const Value(1),
            type: TransactionType.creditCardPurchase,
            amount: 2000.0,
            description: const Value('Groceries'),
          ),
        );

    final updatedTxs = await upgradedDb.select(upgradedDb.transactions).get();
    expect(updatedTxs.length, equals(2));
    expect(updatedTxs.last.creditCardId, equals(1));
    expect(updatedTxs.last.accountId, isNull);

    await upgradedDb.close();
  });
}
