import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_and_money_manager/core/database/app_database.dart';
import 'package:expense_tracker_and_money_manager/core/database/tables/accounts.dart';
import 'package:expense_tracker_and_money_manager/core/database/tables/transactions.dart';
import 'package:expense_tracker_and_money_manager/data/models/credit_card_extensions.dart';
import 'package:expense_tracker_and_money_manager/data/repositories/account_repository.dart';
import 'package:expense_tracker_and_money_manager/data/repositories/budget_repository.dart';
import 'package:expense_tracker_and_money_manager/data/repositories/credit_card_repository.dart';
import 'package:expense_tracker_and_money_manager/data/services/budget_service.dart';
import 'package:expense_tracker_and_money_manager/data/services/financial_service.dart';
import 'package:expense_tracker_and_money_manager/screens/transactions/transactions_screen.dart';

void main() {
  late AppDatabase database;
  late AccountRepository accountRepository;
  late CreditCardRepository creditCardRepository;
  late BudgetRepository budgetRepository;
  late FinancialService financialService;
  late BudgetService budgetService;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    accountRepository = DriftAccountRepository(database);
    creditCardRepository = DriftCreditCardRepository(database);
    budgetRepository = DriftBudgetRepository(database);
    financialService = DriftFinancialService(database);
    budgetService = DriftBudgetService(database, budgetRepository);
  });

  tearDown(() async {
    await database.close();
  });

  group('Milestone 7: Credit Card Purchase & Liability Accounting Tests', () {
    test('Test 1 — Credit card purchase increases liability and creates transaction',
        () async {
      final cardId = await creditCardRepository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 5000.0,
      );

      final txId = await financialService.recordCreditCardPurchase(
        creditCardId: cardId,
        amount: 2000.0,
        description: 'Groceries',
      );

      final updatedCard = await creditCardRepository.getCreditCardById(cardId);
      expect(updatedCard, isNotNull);
      expect(updatedCard!.outstandingBalance, equals(7000.0));
      expect(updatedCard.availableCredit, equals(93000.0));

      final transactions =
          await financialService.getTransactionsWithAccount();
      expect(transactions.length, equals(1));
      expect(transactions.first.transaction.id, equals(txId));
      expect(transactions.first.transaction.type,
          equals(TransactionType.creditCardPurchase));
      expect(transactions.first.transaction.amount, equals(2000.0));
      expect(transactions.first.transaction.creditCardId, equals(cardId));
      expect(transactions.first.creditCard, isNotNull);
      expect(transactions.first.creditCard!.name, equals('HDFC Millennia'));
    });

    test('Test 2 — Asset balance unchanged after credit card purchase',
        () async {
      final bankId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 10000.0,
      );

      final cardId = await creditCardRepository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 5000.0,
      );

      await financialService.recordCreditCardPurchase(
        creditCardId: cardId,
        amount: 2000.0,
        description: 'Online Shopping',
      );

      final updatedBank = await accountRepository.getAccountById(bankId);
      expect(updatedBank, isNotNull);
      expect(updatedBank!.balance, equals(10000.0)); // Unchanged!

      final updatedCard = await creditCardRepository.getCreditCardById(cardId);
      expect(updatedCard, isNotNull);
      expect(updatedCard!.outstandingBalance, equals(7000.0));

      final cashAvailable = await financialService.getCashAvailable();
      expect(cashAvailable, equals(10000.0)); // Unchanged!

      final netLiquidity = await financialService.getNetLiquidity();
      expect(netLiquidity, equals(3000.0)); // 10,000 - 7,000
    });

    test('Test 3 — Purchase counts as spending in monthly budget', () async {
      final bankId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 20000.0,
      );

      final cardId = await creditCardRepository.createCreditCard(
        name: 'ICICI Amazon Pay',
        lastFourDigits: '5678',
        creditLimit: 50000.0,
      );

      final now = DateTime(2026, 10, 1);
      await budgetService.setMonthlyBudget(amount: 9000.0, date: now);

      // Existing bank expense
      await financialService.recordExpense(
        accountId: bankId,
        amount: 6000.0,
        transactionDate: now,
      );

      // Credit card purchase
      await financialService.recordCreditCardPurchase(
        creditCardId: cardId,
        amount: 2000.0,
        transactionDate: now,
      );

      final summary = await budgetService.getMonthlyBudgetSummary(date: now);
      expect(summary.spending, equals(8000.0));
      expect(summary.remaining, equals(1000.0));
      expect(summary.status, equals(BudgetStatus.nearLimit));
    });

    test('Test 4 — Over-budget credit-card purchase calculates overrun',
        () async {
      final bankId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 20000.0,
      );

      final cardId = await creditCardRepository.createCreditCard(
        name: 'ICICI Amazon Pay',
        lastFourDigits: '5678',
        creditLimit: 50000.0,
      );

      final now = DateTime(2026, 10, 1);
      await budgetService.setMonthlyBudget(amount: 9000.0, date: now);

      await financialService.recordExpense(
        accountId: bankId,
        amount: 8000.0,
        transactionDate: now,
      );

      await financialService.recordCreditCardPurchase(
        creditCardId: cardId,
        amount: 2000.0,
        transactionDate: now,
      );

      final summary = await budgetService.getMonthlyBudgetSummary(date: now);
      expect(summary.spending, equals(10000.0));
      expect(summary.overrun, equals(1000.0));
      expect(summary.status, equals(BudgetStatus.overBudget));
    });

    test('Test 5 — Exact available credit purchase succeeds', () async {
      final cardId = await creditCardRepository.createCreditCard(
        name: 'Axis Ace',
        lastFourDigits: '9999',
        creditLimit: 50000.0,
        outstandingBalance: 45000.0,
      );

      await financialService.recordCreditCardPurchase(
        creditCardId: cardId,
        amount: 5000.0,
      );

      final updatedCard = await creditCardRepository.getCreditCardById(cardId);
      expect(updatedCard!.outstandingBalance, equals(50000.0));
      expect(updatedCard.availableCredit, equals(0.0));
    });

    test('Test 6 — Exceeding available credit is rejected', () async {
      final cardId = await creditCardRepository.createCreditCard(
        name: 'Axis Ace',
        lastFourDigits: '9999',
        creditLimit: 50000.0,
        outstandingBalance: 45000.0,
      );

      expect(
        () => financialService.recordCreditCardPurchase(
          creditCardId: cardId,
          amount: 5001.0,
        ),
        throwsA(isA<InsufficientCreditException>()),
      );

      final card = await creditCardRepository.getCreditCardById(cardId);
      expect(card!.outstandingBalance, equals(45000.0));

      final transactions =
          await financialService.getTransactionsWithAccount();
      expect(transactions, isEmpty);
    });

    test('Test 7 — Purchase on inactive card is rejected', () async {
      final cardId = await creditCardRepository.createCreditCard(
        name: 'Old Card',
        lastFourDigits: '1111',
        creditLimit: 50000.0,
      );

      await creditCardRepository.deactivateCreditCard(cardId);

      expect(
        () => financialService.recordCreditCardPurchase(
          creditCardId: cardId,
          amount: 500.0,
        ),
        throwsA(isA<InactiveCreditCardException>()),
      );

      final card = await creditCardRepository.getCreditCardById(cardId);
      expect(card!.outstandingBalance, equals(0.0));

      final transactions =
          await financialService.getTransactionsWithAccount();
      expect(transactions, isEmpty);
    });

    test('Test 8 — Zero amount fails validation', () async {
      final cardId = await creditCardRepository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
      );

      expect(
        () => financialService.recordCreditCardPurchase(
          creditCardId: cardId,
          amount: 0.0,
        ),
        throwsA(isA<InvalidTransactionException>()),
      );

      final card = await creditCardRepository.getCreditCardById(cardId);
      expect(card!.outstandingBalance, equals(0.0));

      final transactions =
          await financialService.getTransactionsWithAccount();
      expect(transactions, isEmpty);
    });

    test('Test 9 — Negative amount fails validation', () async {
      final cardId = await creditCardRepository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
      );

      expect(
        () => financialService.recordCreditCardPurchase(
          creditCardId: cardId,
          amount: -500.0,
        ),
        throwsA(isA<InvalidTransactionException>()),
      );

      final card = await creditCardRepository.getCreditCardById(cardId);
      expect(card!.outstandingBalance, equals(0.0));

      final transactions =
          await financialService.getTransactionsWithAccount();
      expect(transactions, isEmpty);
    });

    test('Test 10 — Historical month isolation for credit-card purchases',
        () async {
      final cardId = await creditCardRepository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
      );

      // September 30, 2026 purchase
      await financialService.recordCreditCardPurchase(
        creditCardId: cardId,
        amount: 2000.0,
        transactionDate: DateTime(2026, 9, 30),
      );

      final sepSpending = await budgetService.getMonthlyExpenseTotal(
        month: DateTime(2026, 9, 1),
      );
      expect(sepSpending, equals(2000.0));

      final octSpending = await budgetService.getMonthlyExpenseTotal(
        month: DateTime(2026, 10, 1),
      );
      expect(octSpending, equals(0.0));
    });

    test('Test 11 — Atomicity rollback on invalid card or error', () async {
      expect(
        () => financialService.recordCreditCardPurchase(
          creditCardId: 99999, // Non-existent card
          amount: 500.0,
        ),
        throwsA(isA<InvalidTransactionException>()),
      );

      final transactions =
          await financialService.getTransactionsWithAccount();
      expect(transactions, isEmpty);
    });
  });

  group('Milestone 7: Transactions UI Widget Tests with Credit Card Purchases',
      () {
    Widget buildTestWidget() {
      return MaterialApp(
        home: TransactionsScreen(
          financialService: financialService,
          accountRepository: accountRepository,
          creditCardRepository: creditCardRepository,
        ),
      );
    }

    testWidgets(
        'Selecting Card purchase shows credit card dropdown and hides account dropdown',
        (WidgetTester tester) async {
      await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 10000.0,
      );

      await creditCardRepository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 5000.0,
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open Add Transaction
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Initially Expense is selected -> Account is visible
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Credit Card'), findsNothing);

      // Tap Card segment
      await tester.tap(find.text('Card'));
      await tester.pumpAndSettle();

      // Now Credit Card is visible -> Account is hidden
      expect(find.text('Credit Card'), findsOneWidget);
      expect(find.text('Account'), findsNothing);
      expect(find.text('HDFC Millennia ****1234'), findsOneWidget);
    });

    testWidgets('Validating credit limit in UI prevents submitting over-limit',
        (WidgetTester tester) async {
      await creditCardRepository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 10000.0,
        outstandingBalance: 8000.0, // Available: 2000
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Card'));
      await tester.pumpAndSettle();

      // Enter amount exceeding available credit (2500 > 2000)
      await tester.enterText(find.widgetWithText(TextFormField, '0'), '2500');
      await tester.ensureVisible(find.text('Save Transaction'));
      await tester.tap(find.text('Save Transaction'));
      await tester.pumpAndSettle();

      expect(find.text('Insufficient available credit'), findsOneWidget);
    });

    testWidgets(
        'Credit card purchase can be submitted and renders in transaction list',
        (WidgetTester tester) async {
      final cardId = await creditCardRepository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 5000.0,
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Card'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, '0'), '2000');
      await tester.enterText(
          find.widgetWithText(TextFormField,
              'e.g. Salary, Groceries, Electricity Bill'),
          'Groceries');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save Transaction'));
      await tester.tap(find.text('Save Transaction'));
      await tester.pumpAndSettle();

      // Verify list renders purchase
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('-₹2,000'), findsOneWidget);
      expect(find.text('HDFC Millennia ****1234'), findsOneWidget);

      // Verify credit card outstanding balance updated
      final updatedCard = await creditCardRepository.getCreditCardById(cardId);
      expect(updatedCard!.outstandingBalance, equals(7000.0));
    });
  });
}
