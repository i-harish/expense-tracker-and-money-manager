import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_and_money_manager/core/database/app_database.dart';
import 'package:expense_tracker_and_money_manager/data/models/credit_card_extensions.dart';
import 'package:expense_tracker_and_money_manager/data/repositories/credit_card_repository.dart';

void main() {
  late AppDatabase database;
  late CreditCardRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftCreditCardRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Milestone 6: Credit Card Repository & Domain Unit Tests', () {
    test('Test 1 — Create credit card and verify persistence', () async {
      final cardId = await repository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 0.0,
      );

      expect(cardId, isPositive);
      final card = await repository.getCreditCardById(cardId);
      expect(card, isNotNull);
      expect(card!.name, 'HDFC Millennia');
      expect(card.lastFourDigits, '1234');
      expect(card.creditLimit, 100000.0);
      expect(card.outstandingBalance, 0.0);
      expect(card.isActive, isTrue);
    });

    test('Test 2 — Initial outstanding and available credit', () async {
      final cardId = await repository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 5000.0,
      );

      final card = await repository.getCreditCardById(cardId);
      expect(card, isNotNull);
      expect(card!.outstandingBalance, 5000.0);
      expect(card.availableCredit, 95000.0);
    });

    test('Test 3 — Invalid outstanding exceeds limit or negative rejected',
        () async {
      // Outstanding > limit
      expect(
        () => repository.createCreditCard(
          name: 'HDFC Millennia',
          lastFourDigits: '1234',
          creditLimit: 100000.0,
          outstandingBalance: 120000.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Negative outstanding
      expect(
        () => repository.createCreditCard(
          name: 'HDFC Millennia',
          lastFourDigits: '1234',
          creditLimit: 100000.0,
          outstandingBalance: -500.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Verify no card was persisted
      final cards = await repository.getAllCreditCards();
      expect(cards, isEmpty);
    });

    test('Test 4 — Invalid credit limit rejected (zero & negative)', () async {
      expect(
        () => repository.createCreditCard(
          name: 'HDFC Millennia',
          lastFourDigits: '1234',
          creditLimit: 0.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => repository.createCreditCard(
          name: 'HDFC Millennia',
          lastFourDigits: '1234',
          creditLimit: -10000.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Test 5 — Invalid last four digits rejected', () async {
      for (final invalid in ['123', '12345', '12AB', '', '    ']) {
        expect(
          () => repository.createCreditCard(
            name: 'HDFC Millennia',
            lastFourDigits: invalid,
            creditLimit: 100000.0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      }
    });

    test('Test 6 — Multiple cards created and returned in active list',
        () async {
      final id1 = await repository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
      );

      final id2 = await repository.createCreditCard(
        name: 'ICICI Amazon',
        lastFourDigits: '5678',
        creditLimit: 75000.0,
      );

      final activeCards = await repository.getActiveCreditCards();
      expect(activeCards.length, 2);
      expect(activeCards.map((c) => c.id), containsAll([id1, id2]));
    });

    test('Test 7 — Edit card persists new name, limit, cycle & due days',
        () async {
      final cardId = await repository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 5000.0,
      );

      final updated = await repository.updateCreditCard(
        id: cardId,
        name: 'HDFC Regalia',
        lastFourDigits: '1234',
        creditLimit: 150000.0,
        billingCycleDay: 15,
        paymentDueDay: 5,
      );

      expect(updated, isTrue);

      final card = await repository.getCreditCardById(cardId);
      expect(card, isNotNull);
      expect(card!.name, 'HDFC Regalia');
      expect(card.creditLimit, 150000.0);
      expect(card.billingCycleDay, 15);
      expect(card.paymentDueDay, 5);
      expect(card.outstandingBalance, 5000.0); // Outstanding unchanged
    });

    test(
        'Test 8 — Deactivate card removes from active list but keeps in database',
        () async {
      final id1 = await repository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
      );

      final id2 = await repository.createCreditCard(
        name: 'ICICI Amazon',
        lastFourDigits: '5678',
        creditLimit: 75000.0,
      );

      // Deactivate ICICI card
      final deactivated = await repository.deactivateCreditCard(id2);
      expect(deactivated, isTrue);

      final activeCards = await repository.getActiveCreditCards();
      expect(activeCards.length, 1);
      expect(activeCards.first.id, id1);

      // Record still exists in all cards
      final allCards = await repository.getAllCreditCards();
      expect(allCards.length, 2);
      final deactivatedCard = allCards.firstWhere((c) => c.id == id2);
      expect(deactivatedCard.isActive, isFalse);
    });

    test('Test 9 — Available credit calculation', () async {
      final cardId = await repository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 25000.0,
      );

      final card = await repository.getCreditCardById(cardId);
      expect(card, isNotNull);
      expect(card!.creditLimit, 100000.0);
      expect(card.outstandingBalance, 25000.0);
      expect(card.availableCredit, 75000.0);
    });

    test('Test 10 — Credit utilization calculation', () async {
      final cardId = await repository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 25000.0,
      );

      final card = await repository.getCreditCardById(cardId);
      expect(card, isNotNull);
      expect(card!.utilizationPercentage, 25.0);
    });
  });
}
