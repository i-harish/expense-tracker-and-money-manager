import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/database/tables/accounts.dart';
import '../../core/database/tables/transactions.dart';

class InsufficientBalanceException implements Exception {
  final String message;
  InsufficientBalanceException([this.message = 'Insufficient balance']);
  @override
  String toString() => message;
}

class InsufficientCreditException implements Exception {
  final String message;
  InsufficientCreditException([this.message = 'Insufficient available credit']);
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

class InactiveCreditCardException implements Exception {
  final String message;
  InactiveCreditCardException(
      [this.message = 'Cannot record transaction for an inactive credit card']);
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
  final Account? account;
  final CreditCard? creditCard;

  const TransactionWithAccount({
    required this.transaction,
    this.account,
    this.creditCard,
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

  Future<int> recordCreditCardPurchase({
    required int creditCardId,
    required double amount,
    String? description,
    DateTime? transactionDate,
  });

  Future<int> recordCreditCardPayment({
    required int creditCardId,
    required int sourceAccountId,
    required double amount,
    String? description,
    DateTime? transactionDate,
  });

  Future<List<TransactionWithAccount>> getTransactionsWithAccount();

  Future<double> getCashAvailable();

  Future<double> getTotalCreditCardOutstanding();

  Future<double> getNetLiquidity();
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
              accountId: Value(accountId),
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
              accountId: Value(accountId),
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
  Future<int> recordCreditCardPurchase({
    required int creditCardId,
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
      final creditCard = await (_db.select(_db.creditCards)
            ..where((tbl) => tbl.id.equals(creditCardId)))
          .getSingleOrNull();

      if (creditCard == null) {
        throw InvalidTransactionException('Credit card not found');
      }

      if (!creditCard.isActive) {
        throw InactiveCreditCardException(
            'Cannot record transaction for an inactive credit card');
      }

      final availableCredit =
          creditCard.creditLimit - creditCard.outstandingBalance;
      if (amount > availableCredit) {
        throw InsufficientCreditException('Insufficient available credit');
      }

      final newOutstanding = creditCard.outstandingBalance + amount;

      await (_db.update(_db.creditCards)
            ..where((tbl) => tbl.id.equals(creditCardId)))
          .write(
        CreditCardsCompanion(
          outstandingBalance: Value(newOutstanding),
          updatedAt: Value(now),
        ),
      );

      final transactionId = await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              creditCardId: Value(creditCardId),
              type: TransactionType.creditCardPurchase,
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
  Future<int> recordCreditCardPayment({
    required int creditCardId,
    required int sourceAccountId,
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
      final creditCard = await (_db.select(_db.creditCards)
            ..where((tbl) => tbl.id.equals(creditCardId)))
          .getSingleOrNull();

      if (creditCard == null) {
        throw InvalidTransactionException('Credit card not found');
      }

      if (!creditCard.isActive) {
        throw InactiveCreditCardException(
            'Cannot record transaction for an inactive credit card');
      }

      final account = await (_db.select(_db.accounts)
            ..where((tbl) => tbl.id.equals(sourceAccountId)))
          .getSingleOrNull();

      if (account == null) {
        throw InvalidTransactionException('Account not found');
      }

      if (!account.isActive) {
        throw InactiveAccountException(
            'Cannot record transaction for an inactive account');
      }

      if (account.type != AccountType.bank &&
          account.type != AccountType.savings &&
          account.type != AccountType.cash) {
        throw InvalidTransactionException(
            'Source account must be an asset account');
      }

      if (amount > creditCard.outstandingBalance) {
        throw InvalidTransactionException(
            'Payment exceeds outstanding balance');
      }

      if (amount > account.balance) {
        throw InsufficientBalanceException('Insufficient account balance');
      }

      final newOutstanding = creditCard.outstandingBalance - amount;
      final newAccountBalance = account.balance - amount;

      await (_db.update(_db.creditCards)
            ..where((tbl) => tbl.id.equals(creditCardId)))
          .write(
        CreditCardsCompanion(
          outstandingBalance: Value(newOutstanding),
          updatedAt: Value(now),
        ),
      );

      await (_db.update(_db.accounts)
            ..where((tbl) => tbl.id.equals(sourceAccountId)))
          .write(
        AccountsCompanion(
          balance: Value(newAccountBalance),
          updatedAt: Value(now),
        ),
      );

      final transactionId = await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              accountId: Value(sourceAccountId),
              creditCardId: Value(creditCardId),
              type: TransactionType.creditCardPayment,
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
      leftOuterJoin(
        _db.accounts,
        _db.accounts.id.equalsExp(_db.transactions.accountId),
      ),
      leftOuterJoin(
        _db.creditCards,
        _db.creditCards.id.equalsExp(_db.transactions.creditCardId),
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
        account: row.readTableOrNull(_db.accounts),
        creditCard: row.readTableOrNull(_db.creditCards),
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

  @override
  Future<double> getTotalCreditCardOutstanding() async {
    final activeCards = await (_db.select(_db.creditCards)
          ..where((tbl) => tbl.isActive.equals(true)))
        .get();

    return activeCards.fold<double>(
      0.0,
      (sum, card) => sum + card.outstandingBalance,
    );
  }

  @override
  Future<double> getNetLiquidity() async {
    final cash = await getCashAvailable();
    final creditOutstanding = await getTotalCreditCardOutstanding();
    return cash - creditOutstanding;
  }
}

