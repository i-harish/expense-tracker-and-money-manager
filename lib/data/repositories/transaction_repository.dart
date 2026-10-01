import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/database/tables/transactions.dart';

abstract class TransactionRepository {
  Future<int> createTransaction({
    int? accountId,
    int? creditCardId,
    required TransactionType type,
    required double amount,
    String? description,
    DateTime? transactionDate,
  });

  Future<Transaction?> getTransactionById(int id);

  Future<List<Transaction>> getAllTransactions();

  Future<List<Transaction>> getTransactionsByAccountId(int accountId);

  Future<List<Transaction>> getTransactionsByCreditCardId(int creditCardId);

  Future<int> deleteTransaction(int id);
}

class DriftTransactionRepository implements TransactionRepository {
  final AppDatabase _db;

  DriftTransactionRepository(this._db);

  @override
  Future<int> createTransaction({
    int? accountId,
    int? creditCardId,
    required TransactionType type,
    required double amount,
    String? description,
    DateTime? transactionDate,
  }) async {
    final now = DateTime.now();
    final effectiveDate = transactionDate ?? now;

    return _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            accountId: Value(accountId),
            creditCardId: Value(creditCardId),
            type: type,
            amount: amount,
            description: Value(description),
            transactionDate: Value(effectiveDate),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  @override
  Future<Transaction?> getTransactionById(int id) async {
    return (_db.select(_db.transactions)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<Transaction>> getAllTransactions() async {
    return (_db.select(_db.transactions)
          ..orderBy([
            (tbl) => OrderingTerm(
                  expression: tbl.transactionDate,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  @override
  Future<List<Transaction>> getTransactionsByAccountId(int accountId) async {
    return (_db.select(_db.transactions)
          ..where((tbl) => tbl.accountId.equals(accountId))
          ..orderBy([
            (tbl) => OrderingTerm(
                  expression: tbl.transactionDate,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  @override
  Future<List<Transaction>> getTransactionsByCreditCardId(
      int creditCardId) async {
    return (_db.select(_db.transactions)
          ..where((tbl) => tbl.creditCardId.equals(creditCardId))
          ..orderBy([
            (tbl) => OrderingTerm(
                  expression: tbl.transactionDate,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  @override
  Future<int> deleteTransaction(int id) async {
    return (_db.delete(_db.transactions)..where((tbl) => tbl.id.equals(id)))
        .go();
  }
}
