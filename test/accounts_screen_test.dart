import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_and_money_manager/core/database/app_database.dart';
import 'package:expense_tracker_and_money_manager/data/repositories/account_repository.dart';
import 'package:expense_tracker_and_money_manager/screens/accounts/accounts_screen.dart';

void main() {
  late AppDatabase database;
  late AccountRepository accountRepository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    accountRepository = DriftAccountRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: AccountsScreen(accountRepository: accountRepository),
    );
  }

  group('Milestone 3: Accounts Screen UI Tests', () {
    testWidgets('Empty state renders when there are no active accounts',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('No accounts yet'), findsOneWidget);
      expect(find.text('Add your first bank, savings, or cash account.'),
          findsOneWidget);
      expect(find.text('Add Account'), findsWidgets);
    });

    testWidgets('Add Account dialog opens and validates input',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap Add Account FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify Dialog opens
      expect(find.text('Add Account'), findsWidgets);
      expect(find.text('Account Name'), findsOneWidget);
      expect(find.text('Account Type'), findsOneWidget);
      expect(find.text('Opening Balance'), findsOneWidget);

      // Attempt to submit empty form
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      // Verify validation error messages
      expect(find.text('Account name is required'), findsOneWidget);
      expect(find.text('Opening balance is required'), findsOneWidget);
    });

    testWidgets('Valid account can be submitted and rendered in list',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open Add Account
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Enter valid data
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.first, 'Main Bank');
      await tester.enterText(textFields.last, '10000');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      // Verify account appears in list
      expect(find.text('Main Bank'), findsOneWidget);
      expect(find.text('Bank'), findsOneWidget);
      expect(find.text('₹10,000'), findsOneWidget);
      expect(find.text('No accounts yet'), findsNothing);
    });
  });
}
