import 'dart:io';

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
import 'package:expense_tracker_and_money_manager/screens/credit_cards/credit_cards_screen.dart';
import 'package:expense_tracker_and_money_manager/screens/transactions/widgets/transaction_form_dialog.dart';

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

  group('Milestone 8: Credit Card Bill Payment Tests', () {
    test('Test 1 — Partial payment', () async {
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

      final txId = await financialService.recordCreditCardPayment(
        creditCardId: cardId,
        sourceAccountId: bankId,
        amount: 2000.0,
        description: 'HDFC Millennia Bill Payment',
      );

      final updatedBank = await accountRepository.getAccountById(bankId);
      expect(updatedBank!.balance, equals(8000.0));

      final updatedCard = await creditCardRepository.getCreditCardById(cardId);
      expect(updatedCard!.outstandingBalance, equals(3000.0));
      expect(updatedCard.availableCredit, equals(97000.0));

      final transactions = await financialService.getTransactionsWithAccount();
      expect(transactions.length, equals(1));
      expect(transactions.first.transaction.id, equals(txId));
      expect(transactions.first.transaction.type,
          equals(TransactionType.creditCardPayment));
      expect(transactions.first.transaction.amount, equals(2000.0));
      expect(transactions.first.transaction.accountId, equals(bankId));
      expect(transactions.first.transaction.creditCardId, equals(cardId));
      expect(transactions.first.account!.name, equals('Main Bank'));
      expect(transactions.first.creditCard!.name, equals('HDFC Millennia'));
    });

    test('Test 2 — Full payment', () async {
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

      await financialService.recordCreditCardPayment(
        creditCardId: cardId,
        sourceAccountId: bankId,
        amount: 5000.0,
      );

      final updatedBank = await accountRepository.getAccountById(bankId);
      expect(updatedBank!.balance, equals(5000.0));

      final updatedCard = await creditCardRepository.getCreditCardById(cardId);
      expect(updatedCard!.outstandingBalance, equals(0.0));
      expect(updatedCard.availableCredit, equals(100000.0));
    });

    test('Test 3 — Payment exceeds outstanding', () async {
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

      expect(
        () => financialService.recordCreditCardPayment(
          creditCardId: cardId,
          sourceAccountId: bankId,
          amount: 5001.0,
        ),
        throwsA(isA<InvalidTransactionException>()),
      );

      final updatedCard = await creditCardRepository.getCreditCardById(cardId);
      expect(updatedCard!.outstandingBalance, equals(5000.0));

      final updatedBank = await accountRepository.getAccountById(bankId);
      expect(updatedBank!.balance, equals(10000.0));

      final transactions = await financialService.getTransactionsWithAccount();
      expect(transactions, isEmpty);
    });

    test('Test 4 — Insufficient asset balance', () async {
      final bankId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 1000.0,
      );

      final cardId = await creditCardRepository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 5000.0,
      );

      expect(
        () => financialService.recordCreditCardPayment(
          creditCardId: cardId,
          sourceAccountId: bankId,
          amount: 2000.0,
        ),
        throwsA(isA<InsufficientBalanceException>()),
      );

      final updatedBank = await accountRepository.getAccountById(bankId);
      expect(updatedBank!.balance, equals(1000.0));

      final updatedCard = await creditCardRepository.getCreditCardById(cardId);
      expect(updatedCard!.outstandingBalance, equals(5000.0));

      final transactions = await financialService.getTransactionsWithAccount();
      expect(transactions, isEmpty);
    });

    test('Test 5 — Exact available asset balance', () async {
      final bankId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 2000.0,
      );

      final cardId = await creditCardRepository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 5000.0,
      );

      await financialService.recordCreditCardPayment(
        creditCardId: cardId,
        sourceAccountId: bankId,
        amount: 2000.0,
      );

      final updatedBank = await accountRepository.getAccountById(bankId);
      expect(updatedBank!.balance, equals(0.0));

      final updatedCard = await creditCardRepository.getCreditCardById(cardId);
      expect(updatedCard!.outstandingBalance, equals(3000.0));
    });

    test('Test 6 — Zero payment', () async {
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

      expect(
        () => financialService.recordCreditCardPayment(
          creditCardId: cardId,
          sourceAccountId: bankId,
          amount: 0.0,
        ),
        throwsA(isA<InvalidTransactionException>()),
      );
    });

    test('Test 7 — Negative payment', () async {
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

      expect(
        () => financialService.recordCreditCardPayment(
          creditCardId: cardId,
          sourceAccountId: bankId,
          amount: -500.0,
        ),
        throwsA(isA<InvalidTransactionException>()),
      );
    });

    test('Test 8 — Inactive card', () async {
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

      await creditCardRepository.deactivateCreditCard(cardId);

      expect(
        () => financialService.recordCreditCardPayment(
          creditCardId: cardId,
          sourceAccountId: bankId,
          amount: 500.0,
        ),
        throwsA(isA<InactiveCreditCardException>()),
      );

      final updatedBank = await accountRepository.getAccountById(bankId);
      expect(updatedBank!.balance, equals(10000.0));

      final updatedCard = await creditCardRepository.getCreditCardById(cardId);
      expect(updatedCard!.outstandingBalance, equals(5000.0));
    });

    test('Test 9 — Inactive asset account', () async {
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

      await accountRepository.deactivateAccount(bankId);

      expect(
        () => financialService.recordCreditCardPayment(
          creditCardId: cardId,
          sourceAccountId: bankId,
          amount: 500.0,
        ),
        throwsA(isA<InactiveAccountException>()),
      );

      final updatedBank = await accountRepository.getAccountById(bankId);
      expect(updatedBank!.balance, equals(10000.0));

      final updatedCard = await creditCardRepository.getCreditCardById(cardId);
      expect(updatedCard!.outstandingBalance, equals(5000.0));
    });

    test('Test 10 — Budget is unchanged by payment', () async {
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

      await budgetService.setMonthlyBudget(amount: 9000.0);

      // Create an existing expense of 6,000
      await financialService.recordExpense(
        accountId: bankId,
        amount: 6000.0,
        description: 'Rent',
      );

      final summaryBefore = await budgetService.getMonthlyBudgetSummary();
      expect(summaryBefore.spending, equals(6000.0));

      // Make card payment of 2,000
      await financialService.recordCreditCardPayment(
        creditCardId: cardId,
        sourceAccountId: bankId,
        amount: 2000.0,
      );

      final summaryAfter = await budgetService.getMonthlyBudgetSummary();
      expect(summaryAfter.spending, equals(6000.0)); // Unchanged!
    });

    test('Test 11 — Purchase followed by payment', () async {
      final bankId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 10000.0,
      );

      final cardId = await creditCardRepository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 0.0,
      );

      // 1. Purchase of 3,000
      await financialService.recordCreditCardPurchase(
        creditCardId: cardId,
        amount: 3000.0,
        description: 'Flight Tickets',
      );

      var bank = await accountRepository.getAccountById(bankId);
      var card = await creditCardRepository.getCreditCardById(cardId);
      var spending = await budgetService.getMonthlyExpenseTotal(
        month: DateTime.now(),
      );

      expect(bank!.balance, equals(10000.0));
      expect(card!.outstandingBalance, equals(3000.0));
      expect(spending, equals(3000.0));

      // 2. Bill Payment of 3,000
      await financialService.recordCreditCardPayment(
        creditCardId: cardId,
        sourceAccountId: bankId,
        amount: 3000.0,
      );

      bank = await accountRepository.getAccountById(bankId);
      card = await creditCardRepository.getCreditCardById(cardId);
      spending = await budgetService.getMonthlyExpenseTotal(
        month: DateTime.now(),
      );

      expect(bank!.balance, equals(7000.0));
      expect(card!.outstandingBalance, equals(0.0));
      expect(spending, equals(3000.0)); // Still 3,000, NOT double counted!
    });

    test('Test 12 — Partial payment after purchase', () async {
      final bankId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 10000.0,
      );

      final cardId = await creditCardRepository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 0.0,
      );

      // Purchase of 4,000
      await financialService.recordCreditCardPurchase(
        creditCardId: cardId,
        amount: 4000.0,
      );

      // Partial payment of 1,500
      await financialService.recordCreditCardPayment(
        creditCardId: cardId,
        sourceAccountId: bankId,
        amount: 1500.0,
      );

      final bank = await accountRepository.getAccountById(bankId);
      final card = await creditCardRepository.getCreditCardById(cardId);
      final spending = await budgetService.getMonthlyExpenseTotal(
        month: DateTime.now(),
      );

      expect(bank!.balance, equals(8500.0));
      expect(card!.outstandingBalance, equals(2500.0));
      expect(spending, equals(4000.0)); // NOT 5,500
    });

    test('Test 13 — Net liquidity remains unchanged after bill payment',
        () async {
      final bankId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 10000.0,
      );
      await accountRepository.createAccount(
        name: 'Savings',
        type: AccountType.savings,
        balance: 5000.0,
      );
      await accountRepository.createAccount(
        name: 'Cash',
        type: AccountType.cash,
        balance: 2000.0,
      );

      final cardId = await creditCardRepository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 5000.0,
      );

      // Before payment
      final cashBefore = await financialService.getCashAvailable();
      final outstandingBefore =
          await financialService.getTotalCreditCardOutstanding();
      final netLiquidityBefore = await financialService.getNetLiquidity();

      expect(cashBefore, equals(17000.0));
      expect(outstandingBefore, equals(5000.0));
      expect(netLiquidityBefore, equals(12000.0));

      // Pay 2,000 from Bank
      await financialService.recordCreditCardPayment(
        creditCardId: cardId,
        sourceAccountId: bankId,
        amount: 2000.0,
      );

      // After payment
      final cashAfter = await financialService.getCashAvailable();
      final outstandingAfter =
          await financialService.getTotalCreditCardOutstanding();
      final netLiquidityAfter = await financialService.getNetLiquidity();

      expect(cashAfter, equals(15000.0));
      expect(outstandingAfter, equals(3000.0));
      expect(netLiquidityAfter, equals(12000.0)); // Mathematically unchanged!
    });

    test('Test 14 — Persistence across database instances', () async {
      final tempDir = await Directory.systemTemp.createTemp('persist_test_');
      final dbFile = File('${tempDir.path}/test_db.sqlite');

      final db1 = AppDatabase.forTesting(NativeDatabase(dbFile));
      final accRepo1 = DriftAccountRepository(db1);
      final ccRepo1 = DriftCreditCardRepository(db1);
      final finService1 = DriftFinancialService(db1);
      final bankId = await accRepo1.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 10000.0,
      );
      final cardId = await ccRepo1.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 5000.0,
      );

      await finService1.recordCreditCardPayment(
        creditCardId: cardId,
        sourceAccountId: bankId,
        amount: 2000.0,
        description: 'Persistence Bill Payment',
      );

      await db1.close();

      // Open second connection to the same SQLite file
      final db2 = AppDatabase.forTesting(NativeDatabase(dbFile));
      final accRepo2 = DriftAccountRepository(db2);
      final ccRepo2 = DriftCreditCardRepository(db2);
      final finService2 = DriftFinancialService(db2);
      final budService2 = DriftBudgetService(db2);

      final bank2 = await accRepo2.getAccountById(bankId);
      expect(bank2!.balance, equals(8000.0));

      final card2 = await ccRepo2.getCreditCardById(cardId);
      expect(card2!.outstandingBalance, equals(3000.0));

      final txs2 = await finService2.getTransactionsWithAccount();
      expect(txs2.length, equals(1));
      expect(txs2.first.transaction.type,
          equals(TransactionType.creditCardPayment));
      expect(txs2.first.transaction.amount, equals(2000.0));

      final spending =
          await budService2.getMonthlyExpenseTotal(month: DateTime.now());
      expect(spending, equals(0.0));

      await db2.close();
      await tempDir.delete(recursive: true);
    });
  });

  group('Milestone 8: UI and Widget Tests', () {
    testWidgets('Transaction form displays Card Pay option and dual selectors',
        (tester) async {
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

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionFormDialog(
              financialService: financialService,
              accountRepository: accountRepository,
              creditCardRepository: creditCardRepository,
              initialType: TransactionType.creditCardPayment,
              initialCreditCardId: cardId,
              initialAccountId: bankId,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bill Pay'), findsOneWidget);
      expect(find.text('Credit Card'), findsOneWidget);
      expect(find.text('Pay From'), findsOneWidget);
      expect(find.text('Make Payment'), findsOneWidget);

      // Enter amount exceeding outstanding balance (5,001)
      await tester.enterText(
          find.widgetWithText(TextFormField, '0'), '5001');
      await tester.ensureVisible(find.text('Make Payment'));
      await tester.tap(find.text('Make Payment'));
      await tester.pumpAndSettle();

      expect(find.text('Payment exceeds outstanding balance'), findsOneWidget);

      // Enter valid amount
      await tester.enterText(
          find.widgetWithText(TextFormField, '0'), '2000');
      await tester.ensureVisible(find.text('Make Payment'));
      await tester.tap(find.text('Make Payment'));
      await tester.pumpAndSettle();

      final updatedBank = await accountRepository.getAccountById(bankId);
      expect(updatedBank!.balance, equals(8000.0));

      final updatedCard = await creditCardRepository.getCreditCardById(cardId);
      expect(updatedCard!.outstandingBalance, equals(3000.0));
    });

    testWidgets('Credit Cards screen shows Make Payment and opens dialog',
        (tester) async {
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

      await tester.pumpWidget(
        MaterialApp(
          home: CreditCardsScreen(
            repository: creditCardRepository,
            financialService: financialService,
            accountRepository: accountRepository,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Make Payment'), findsOneWidget);
      await tester.tap(find.text('Make Payment'));
      await tester.pumpAndSettle();

      // Form dialog opens in Card Pay mode
      expect(find.text('Pay From'), findsOneWidget);
      expect(find.text('Make Payment'), findsWidgets);
    });

    testWidgets('Credit Cards screen shows No Payment Due when outstanding is zero',
        (tester) async {
      await creditCardRepository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CreditCardsScreen(
            repository: creditCardRepository,
            financialService: financialService,
            accountRepository: accountRepository,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No Payment Due'), findsOneWidget);
    });
  });
}
