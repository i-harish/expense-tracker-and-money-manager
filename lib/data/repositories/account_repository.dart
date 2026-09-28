import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/database/tables/accounts.dart';

abstract class AccountRepository {
  Future<int> createAccount({
    required String name,
    required AccountType type,
    double balance = 0.0,
    String currency = 'INR',
    bool isActive = true,
  });

  Future<Account?> getAccountById(int id);

  Future<List<Account>> getAllAccounts();

  Future<List<Account>> getActiveAccounts();

  Future<bool> updateAccount(AccountsCompanion account);

  Future<bool> updateAccountDetails({
    required int id,
    required String name,
    required AccountType type,
  });

  Future<bool> deactivateAccount(int id);

  Future<int> deleteAccount(int id);
}

class DriftAccountRepository implements AccountRepository {
  final AppDatabase _db;

  DriftAccountRepository(this._db);

  @override
  Future<int> createAccount({
    required String name,
    required AccountType type,
    double balance = 0.0,
    String currency = 'INR',
    bool isActive = true,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Account name cannot be empty');
    }
    if (balance < 0) {
      throw ArgumentError('Opening balance cannot be negative');
    }

    final now = DateTime.now();
    return _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            name: trimmedName,
            type: type,
            balance: Value(balance),
            currency: Value(currency),
            isActive: Value(isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  @override
  Future<Account?> getAccountById(int id) async {
    return (_db.select(_db.accounts)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<Account>> getAllAccounts() async {
    return _db.select(_db.accounts).get();
  }

  @override
  Future<List<Account>> getActiveAccounts() async {
    return (_db.select(_db.accounts)
          ..where((tbl) => tbl.isActive.equals(true))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt)]))
        .get();
  }

  @override
  Future<bool> updateAccount(AccountsCompanion account) async {
    return _db.update(_db.accounts).replace(account);
  }

  @override
  Future<bool> updateAccountDetails({
    required int id,
    required String name,
    required AccountType type,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Account name cannot be empty');
    }

    final now = DateTime.now();
    final count =
        await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(id)))
            .write(
      AccountsCompanion(
        name: Value(trimmedName),
        type: Value(type),
        updatedAt: Value(now),
      ),
    );
    return count > 0;
  }

  @override
  Future<bool> deactivateAccount(int id) async {
    final now = DateTime.now();
    final count =
        await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(id)))
            .write(
      AccountsCompanion(
        isActive: const Value(false),
        updatedAt: Value(now),
      ),
    );
    return count > 0;
  }

  @override
  Future<int> deleteAccount(int id) async {
    return (_db.delete(_db.accounts)..where((tbl) => tbl.id.equals(id))).go();
  }
}
