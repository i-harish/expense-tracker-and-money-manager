import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_and_money_manager/core/database/app_database.dart';
import 'package:expense_tracker_and_money_manager/core/database/tables/accounts.dart';
import 'package:expense_tracker_and_money_manager/data/repositories/account_repository.dart';
import 'package:expense_tracker_and_money_manager/data/repositories/budget_repository.dart';
import 'package:expense_tracker_and_money_manager/data/services/budget_service.dart';
import 'package:expense_tracker_and_money_manager/data/services/financial_service.dart';
import 'package:expense_tracker_and_money_manager/screens/dashboard/dashboard_screen.dart';

void main() {
  late AppDatabase database;
  late AccountRepository accountRepository;
  late BudgetRepository budgetRepository;
  late FinancialService financialService;
  late BudgetService budgetService;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    accountRepository = DriftAccountRepository(database);
    budgetRepository = DriftBudgetRepository(database);
    financialService = DriftFinancialService(database);
    budgetService = DriftBudgetService(database, budgetRepository);
  });

  tearDown(() async {
    await database.close();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: DashboardScreen(
          financialService: financialService,
          budgetService: budgetService,
        ),
      ),
    );
  }

  group('Milestone 5: Dashboard Screen & Monthly Budget UI Tests', () {
    testWidgets('Budget summary renders with default budget and zero spending',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('MONTHLY BUDGET'), findsOneWidget);
      expect(find.text('₹9,000'), findsWidgets);
      expect(find.text('SPENT'), findsOneWidget);
      expect(find.text('₹0'), findsWidgets);
      expect(find.text('REMAINING'), findsOneWidget);
      expect(find.text('UNDER BUDGET (0.0%)'), findsOneWidget);
    });

    testWidgets('Monthly spending and remaining amounts are displayed correctly',
        (WidgetTester tester) async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 20000.0,
      );

      await financialService.recordExpense(
        accountId: accountId,
        amount: 6500.0,
        description: 'Shopping',
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('MONTHLY BUDGET'), findsOneWidget);
      expect(find.text('₹9,000'), findsOneWidget);
      expect(find.text('₹6,500'), findsOneWidget);
      expect(find.text('₹2,500'), findsOneWidget);
      expect(find.text('UNDER BUDGET (72.2%)'), findsOneWidget);
    });

    testWidgets('Over-budget state renders overrun and over budget status',
        (WidgetTester tester) async {
      final accountId = await accountRepository.createAccount(
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 20000.0,
      );

      await financialService.recordExpense(
        accountId: accountId,
        amount: 9500.0,
        description: 'Big Expense',
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('OVER BUDGET'), findsOneWidget);
      expect(find.text('₹9,500'), findsOneWidget);
      expect(find.text('₹500'), findsOneWidget);
      expect(find.text('OVER BUDGET (105.6%)'), findsOneWidget);
    });

    testWidgets(
        'Edit Budget dialog opens, validates input, and updates budget',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap Edit Budget icon
      await tester.tap(find.byTooltip('Edit Budget'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Monthly Budget'), findsOneWidget);
      expect(find.text('Budget Amount'), findsOneWidget);

      // Submit invalid amount (0)
      await tester.enterText(find.byType(TextFormField), '0');
      await tester.tap(find.text('Save Budget'));
      await tester.pumpAndSettle();

      expect(find.text('Budget must be greater than zero'), findsOneWidget);

      // Submit valid amount (10000)
      await tester.enterText(find.byType(TextFormField), '10000');
      await tester.tap(find.text('Save Budget'));
      await tester.pumpAndSettle();

      // Verify dashboard updated
      expect(find.text('₹10,000'), findsWidgets);
    });
  });
}
