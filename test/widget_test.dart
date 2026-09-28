import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_and_money_manager/app.dart';
import 'package:expense_tracker_and_money_manager/core/database/app_database.dart';

void main() {
  setUp(() {
    AppDatabase.instance = AppDatabase.forTesting(NativeDatabase.memory());
  });

  group('Family Money Manager Dashboard Shell Tests', () {
    testWidgets('App starts and displays basic dashboard shell elements',
        (WidgetTester tester) async {
      await tester.pumpWidget(const FamilyMoneyManagerApp());
      await tester.pumpAndSettle();

      // Verify App Title
      expect(find.text('Family Money Manager'), findsOneWidget);

      // Verify User Greeting
      expect(find.text('Good morning, Harish'), findsOneWidget);

      // Verify Summary Cards
      expect(find.text('CASH AVAILABLE'), findsOneWidget);
      expect(find.text('NET LIQUIDITY'), findsOneWidget);
      expect(find.text('MONTHLY BUDGET'), findsOneWidget);
      expect(find.text('₹9,000'), findsWidgets);
      expect(find.text('SPENT'), findsOneWidget);

      // Verify Recent Transactions Section
      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(find.text('No transactions yet'), findsOneWidget);

      // Verify Navigation Bar and Destinations
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);
      expect(find.text('Credit Cards'), findsOneWidget);
    });

    testWidgets('Navigation between all 4 tabs works properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(const FamilyMoneyManagerApp());
      await tester.pumpAndSettle();

      // Initially on Dashboard
      expect(find.text('Good morning, Harish'), findsOneWidget);

      // Tap Transactions tab
      await tester.tap(find.text('Transactions'));
      await tester.pumpAndSettle();
      expect(find.text('No transactions yet'), findsWidgets);

      // Tap Family tab
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      expect(find.text('Coming soon'), findsWidgets);

      // Tap Credit Cards tab
      await tester.tap(find.text('Credit Cards'));
      await tester.pumpAndSettle();
      expect(find.text('No credit cards yet'), findsWidgets);

      // Tap Dashboard tab to return
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Good morning, Harish'), findsOneWidget);
      expect(find.text('CASH AVAILABLE'), findsOneWidget);
    });
  });
}
