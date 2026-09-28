import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_and_money_manager/core/database/app_database.dart';
import 'package:expense_tracker_and_money_manager/core/database/tables/accounts.dart';
import 'package:expense_tracker_and_money_manager/data/repositories/account_repository.dart';
import 'package:expense_tracker_and_money_manager/data/services/financial_service.dart';
import 'package:expense_tracker_and_money_manager/screens/transactions/transactions_screen.dart';

void main() {
  late AppDatabase database;
  late AccountRepository accountRepository;
  late FinancialService financialService;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    accountRepository = DriftAccountRepository(database);
    financialService = DriftFinancialService(database);
  });

  tearDown(() async {
    await database.close();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: TransactionsScreen(
        financialService: financialService,
        accountRepository: accountRepository,
      ),
    );
  }

  group('Milestone 4: Transactions Screen UI Tests', () {
    testWidgets('Empty state renders when there are no transactions',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No transactions yet'), findsOneWidget);
      expect(find.text('Add your first income or expense.'), findsOneWidget);
      expect(find.text('Add Transaction'), findsWidgets);
    });

    testWidgets('Add Transaction form opens and validates empty/invalid amount',
        (WidgetTester tester) async {
      await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 10000.0,
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open Add Transaction dialog
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Add Transaction'), findsWidgets);
      expect(find.text('Transaction Type'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);

      // Attempt to submit empty form
      await tester.ensureVisible(find.text('Save Transaction'));
      await tester.tap(find.text('Save Transaction'));
      await tester.pumpAndSettle();

      expect(find.text('Amount is required'), findsOneWidget);

      // Attempt to submit 0 amount
      await tester.enterText(
          find.widgetWithText(TextFormField, '0'), '0');
      await tester.ensureVisible(find.text('Save Transaction'));
      await tester.tap(find.text('Save Transaction'));
      await tester.pumpAndSettle();

      expect(find.text('Amount must be greater than zero'), findsOneWidget);
    });

    testWidgets('Valid transaction can be submitted and rendered in list',
        (WidgetTester tester) async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 10000.0,
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open Add Transaction
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Enter valid transaction details
      await tester.enterText(
          find.widgetWithText(TextFormField, '0'), '1500');
      await tester.enterText(
          find.widgetWithText(TextFormField,
              'e.g. Salary, Groceries, Electricity Bill'),
          'Groceries');
      await tester.pumpAndSettle();

      // Submit
      await tester.ensureVisible(find.text('Save Transaction'));
      await tester.tap(find.text('Save Transaction'));
      await tester.pumpAndSettle();

      // Verify transaction appears in list
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('-₹1,500'), findsOneWidget);
      expect(find.text('Main Bank'), findsOneWidget);

      // Verify account balance updated
      final updatedAccount = await accountRepository.getAccountById(accountId);
      expect(updatedAccount!.balance, equals(8500.0));
    });
  });
}
