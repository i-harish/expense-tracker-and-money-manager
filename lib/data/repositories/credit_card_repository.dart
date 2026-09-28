import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

abstract class CreditCardRepository {
  Future<int> createCreditCard({
    required String name,
    required String lastFourDigits,
    required double creditLimit,
    double outstandingBalance = 0.0,
    int? billingCycleDay,
    int? paymentDueDay,
    bool isActive = true,
  });

  Future<CreditCard?> getCreditCardById(int id);

  Future<List<CreditCard>> getAllCreditCards();

  Future<List<CreditCard>> getActiveCreditCards();

  Future<bool> updateCreditCard({
    required int id,
    required String name,
    required String lastFourDigits,
    required double creditLimit,
    int? billingCycleDay,
    int? paymentDueDay,
  });

  Future<bool> deactivateCreditCard(int id);

  Future<int> deleteCreditCard(int id);
}

class DriftCreditCardRepository implements CreditCardRepository {
  final AppDatabase _db;

  DriftCreditCardRepository(this._db);

  @override
  Future<int> createCreditCard({
    required String name,
    required String lastFourDigits,
    required double creditLimit,
    double outstandingBalance = 0.0,
    int? billingCycleDay,
    int? paymentDueDay,
    bool isActive = true,
  }) async {
    final trimmedName = name.trim();
    final trimmedDigits = lastFourDigits.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError('Card name cannot be empty');
    }
    if (!RegExp(r'^\d{4}$').hasMatch(trimmedDigits)) {
      throw ArgumentError('Last four digits must contain exactly four numbers');
    }
    if (creditLimit <= 0) {
      throw ArgumentError('Credit limit must be greater than zero');
    }
    if (outstandingBalance < 0) {
      throw ArgumentError('Initial outstanding balance cannot be negative');
    }
    if (outstandingBalance > creditLimit) {
      throw ArgumentError('Initial outstanding balance cannot exceed credit limit');
    }
    if (billingCycleDay != null &&
        (billingCycleDay < 1 || billingCycleDay > 31)) {
      throw ArgumentError('Billing cycle day must be between 1 and 31');
    }
    if (paymentDueDay != null && (paymentDueDay < 1 || paymentDueDay > 31)) {
      throw ArgumentError('Payment due day must be between 1 and 31');
    }

    final now = DateTime.now();
    return _db.into(_db.creditCards).insert(
          CreditCardsCompanion.insert(
            name: trimmedName,
            lastFourDigits: trimmedDigits,
            creditLimit: creditLimit,
            outstandingBalance: Value(outstandingBalance),
            billingCycleDay: Value(billingCycleDay),
            paymentDueDay: Value(paymentDueDay),
            isActive: Value(isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  @override
  Future<CreditCard?> getCreditCardById(int id) async {
    return (_db.select(_db.creditCards)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<CreditCard>> getAllCreditCards() async {
    return _db.select(_db.creditCards).get();
  }

  @override
  Future<List<CreditCard>> getActiveCreditCards() async {
    return (_db.select(_db.creditCards)
          ..where((tbl) => tbl.isActive.equals(true))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt)]))
        .get();
  }

  @override
  Future<bool> updateCreditCard({
    required int id,
    required String name,
    required String lastFourDigits,
    required double creditLimit,
    int? billingCycleDay,
    int? paymentDueDay,
  }) async {
    final trimmedName = name.trim();
    final trimmedDigits = lastFourDigits.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError('Card name cannot be empty');
    }
    if (!RegExp(r'^\d{4}$').hasMatch(trimmedDigits)) {
      throw ArgumentError('Last four digits must contain exactly four numbers');
    }
    if (creditLimit <= 0) {
      throw ArgumentError('Credit limit must be greater than zero');
    }
    if (billingCycleDay != null &&
        (billingCycleDay < 1 || billingCycleDay > 31)) {
      throw ArgumentError('Billing cycle day must be between 1 and 31');
    }
    if (paymentDueDay != null && (paymentDueDay < 1 || paymentDueDay > 31)) {
      throw ArgumentError('Payment due day must be between 1 and 31');
    }

    final existing = await getCreditCardById(id);
    if (existing == null) {
      throw ArgumentError('Credit card not found');
    }

    if (creditLimit < existing.outstandingBalance) {
      throw ArgumentError(
          'Credit limit cannot be less than current outstanding balance');
    }

    final updatedRows = await (_db.update(_db.creditCards)
          ..where((tbl) => tbl.id.equals(id)))
        .write(
      CreditCardsCompanion(
        name: Value(trimmedName),
        lastFourDigits: Value(trimmedDigits),
        creditLimit: Value(creditLimit),
        billingCycleDay: Value(billingCycleDay),
        paymentDueDay: Value(paymentDueDay),
        updatedAt: Value(DateTime.now()),
      ),
    );

    return updatedRows > 0;
  }

  @override
  Future<bool> deactivateCreditCard(int id) async {
    final updatedRows = await (_db.update(_db.creditCards)
          ..where((tbl) => tbl.id.equals(id)))
        .write(
      CreditCardsCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return updatedRows > 0;
  }

  @override
  Future<int> deleteCreditCard(int id) async {
    return (_db.delete(_db.creditCards)..where((tbl) => tbl.id.equals(id)))
        .go();
  }
}
