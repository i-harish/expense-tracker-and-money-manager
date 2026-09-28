import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_and_money_manager/core/database/app_database.dart';
import 'package:expense_tracker_and_money_manager/data/repositories/credit_card_repository.dart';
import 'package:expense_tracker_and_money_manager/screens/credit_cards/credit_cards_screen.dart';

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

  Widget buildTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: CreditCardsScreen(
          repository: repository,
        ),
      ),
    );
  }

  group('Milestone 6: Credit Cards Screen Widget Tests', () {
    testWidgets('Empty state renders when no credit cards exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No credit cards yet'), findsOneWidget);
      expect(
        find.text(
            'Add your first credit card to track your outstanding balance.'),
        findsOneWidget,
      );
      expect(find.text('Add Credit Card'), findsOneWidget);
    });

    testWidgets(
        'Add card flow validates fields and adds card to active list',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap Add Credit Card in empty state
      await tester.tap(find.text('Add Credit Card'));
      await tester.pumpAndSettle();

      expect(find.text('Card Name'), findsOneWidget);
      expect(find.text('Last 4 Digits'), findsOneWidget);
      expect(find.text('Credit Limit (₹)'), findsOneWidget);

      // Submit empty form -> should show validations
      final submitButton = find.widgetWithText(FilledButton, 'Add Card');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Card name is required'), findsOneWidget);
      expect(find.text('Last 4 digits are required'), findsOneWidget);
      expect(find.text('Credit limit is required'), findsOneWidget);

      // Fill in valid data
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Card Name'), 'HDFC Millennia');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Last 4 Digits'), '1234');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Credit Limit (₹)'), '100000');
      await tester.enterText(
          find.widgetWithText(
              TextFormField, 'Initial Outstanding Balance (₹)'),
          '5000');

      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Card should now be rendered in the list
      expect(find.text('HDFC Millennia'), findsOneWidget);
      expect(find.text('•••• 1234'), findsOneWidget);
      expect(find.text('OUTSTANDING'), findsOneWidget);
      expect(find.text('₹5,000'), findsWidgets);
      expect(find.text('CREDIT LIMIT'), findsOneWidget);
      expect(find.text('₹1,00,000'), findsWidgets);
      expect(find.text('AVAILABLE'), findsOneWidget);
      expect(find.text('₹95,000'), findsWidgets);
      expect(find.text('5.0% Used'), findsOneWidget);
    });

    testWidgets('Multiple cards and total credit liability header render',
        (WidgetTester tester) async {
      await repository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 5000.0,
      );

      await repository.createCreditCard(
        name: 'ICICI Amazon',
        lastFourDigits: '5678',
        creditLimit: 75000.0,
        outstandingBalance: 2000.0,
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('TOTAL CREDIT LIABILITY'), findsOneWidget);
      expect(find.text('₹7,000'), findsOneWidget); // 5000 + 2000
      expect(find.text('TOTAL LIMIT'), findsOneWidget);
      expect(find.text('₹1,75,000'), findsOneWidget);
      expect(find.text('TOTAL AVAILABLE'), findsOneWidget);
      expect(find.text('₹1,68,000'), findsOneWidget);

      expect(find.text('HDFC Millennia'), findsOneWidget);
      expect(find.text('ICICI Amazon'), findsOneWidget);
    });

    testWidgets('Edit credit card updates information in UI',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await repository.createCreditCard(
        name: 'HDFC Millennia',
        lastFourDigits: '1234',
        creditLimit: 100000.0,
        outstandingBalance: 5000.0,
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Tap Edit Card
      await tester.tap(find.text('Edit Card'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Credit Card'), findsOneWidget);

      // Change name & limit
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Card Name'), 'HDFC Regalia');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Credit Limit (₹)'), '150000');

      final saveButton = find.widgetWithText(FilledButton, 'Save Card');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('HDFC Regalia'), findsOneWidget);
      expect(find.text('₹1,50,000'), findsWidgets);
    });

    testWidgets('Deactivate credit card removes it from active list',
        (WidgetTester tester) async {
      await repository.createCreditCard(
        name: 'ICICI Amazon',
        lastFourDigits: '5678',
        creditLimit: 75000.0,
        outstandingBalance: 2000.0,
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('ICICI Amazon'), findsOneWidget);

      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Tap Deactivate
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Deactivate Card'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
      await tester.pumpAndSettle();

      // Card is removed and empty state renders
      expect(find.text('ICICI Amazon'), findsNothing);
      expect(find.text('No credit cards yet'), findsOneWidget);
    });
  });
}
