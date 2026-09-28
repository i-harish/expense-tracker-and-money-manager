import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/database/tables/transactions.dart';

class InsufficientBalanceException implements Exception {
  final String message;
  InsufficientBalanceException([this.message = 'Insufficient balance']);
  @override
  String toString() => message;
}

class InactiveAccountException implements Exception {
  final String message;
  InactiveAccountException(
      [this.message = 'Cannot record transaction for an inactive account']);
  @override
  String toString() => message;
}

class InvalidTransactionException implements Exception {
  final String message;
  InvalidTransactionException(this.message);
  @override
  String toString() => message;
}

class TransactionWithAccount {
  final Transaction transaction;
  final Account account;

  const TransactionWithAccount({
    required this.transaction,
    required this.account,
  });
}

abstract class FinancialService {
  Future<int> recordIncome({
    required int accountId,
    required double amount,
    String? description,
    DateTime? transactionDate,
  });

  Future<int> recordExpense({
    required int accountId,
    required double amount,
    String? description,
    DateTime? transactionDate,
  });

  Future<List<TransactionWithAccount>> getTransactionsWithAccount();

  Future<double> getCashAvailable();
}

class DriftFinancialService implements FinancialService {
  final AppDatabase _db;

  DriftFinancialService(this._db);

  @override
  Future<int> recordIncome({
    required int accountId,
    required double amount,
    String? description,
    DateTime? transactionDate,
  }) async {
    if (amount <= 0) {
      throw InvalidTransactionException('Amount must be greater than zero');
    }

    final now = DateTime.now();
    final effectiveDate = transactionDate ?? now;

    return _db.transaction(() async {
      final account = await (_db.select(_db.accounts)
            ..where((tbl) => tbl.id.equals(accountId)))
          .getSingleOrNull();

      if (account == null) {
        throw InvalidTransactionException('Account not found');
      }

      if (!account.isActive) {
        throw InactiveAccountException(
            'Cannot record transaction for an inactive account');
      }

      final newBalance = account.balance + amount;

      await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(accountId)))
          .write(
        AccountsCompanion(
          balance: Value(newBalance),
          updatedAt: Value(now),
        ),
      );

      final transactionId = await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              accountId: accountId,
              type: TransactionType.income,
              amount: amount,
              description: Value(description?.trim().isEmpty == true
                  ? null
                  : description?.trim()),
              transactionDate: Value(effectiveDate),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      return transactionId;
    });
  }

  @override
  Future<int> recordExpense({
    required int accountId,
    required double amount,
    String? description,
    DateTime? transactionDate,
  }) async {
    if (amount <= 0) {
      throw InvalidTransactionException('Amount must be greater than zero');
    }

    final now = DateTime.now();
    final effectiveDate = transactionDate ?? now;

    return _db.transaction(() async {
      final account = await (_db.select(_db.accounts)
            ..where((tbl) => tbl.id.equals(accountId)))
          .getSingleOrNull();

      if (account == null) {
        throw InvalidTransactionException('Account not found');
      }

      if (!account.isActive) {
        throw InactiveAccountException(
            'Cannot record transaction for an inactive account');
      }

      if (account.balance < amount) {
        throw InsufficientBalanceException(
            'Insufficient balance in ${account.name}');
      }

      final newBalance = account.balance - amount;

      await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(accountId)))
          .write(
        AccountsCompanion(
          balance: Value(newBalance),
          updatedAt: Value(now),
        ),
      );

      final transactionId = await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              accountId: accountId,
              type: TransactionType.expense,
              amount: amount,
              description: Value(description?.trim().isEmpty == true
                  ? null
                  : description?.trim()),
              transactionDate: Value(effectiveDate),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      return transactionId;
    });
  }

  @override
  Future<List<TransactionWithAccount>> getTransactionsWithAccount() async {
    final query = _db.select(_db.transactions).join([
      innerJoin(
        _db.accounts,
        _db.accounts.id.equalsExp(_db.transactions.accountId),
      ),
    ])
      ..orderBy([
        OrderingTerm(
          expression: _db.transactions.transactionDate,
          mode: OrderingMode.desc,
        ),
        OrderingTerm(
          expression: _db.transactions.id,
          mode: OrderingMode.desc,
        ),
      ]);

    final rows = await query.get();
    return rows.map((row) {
      return TransactionWithAccount(
        transaction: row.readTable(_db.transactions),
        account: row.readTable(_db.accounts),
      );
    }).toList();
  }

  @override
  Future<double> getCashAvailable() async {
    final activeAccounts = await (_db.select(_db.accounts)
          ..where((tbl) => tbl.isActive.equals(true)))
        .get();

    return activeAccounts.fold<double>(
      0.0,
      (sum, account) => sum + account.balance,
    );
  }
}
