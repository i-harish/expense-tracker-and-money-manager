import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/accounts.dart';
import 'tables/budgets.dart';
import 'tables/credit_cards.dart';
import 'tables/transactions.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Accounts, Transactions, Budgets, CreditCards])
class AppDatabase extends _$AppDatabase {
  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase();
  static set instance(AppDatabase db) => _instance = db;

  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(creditCards);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'family_money_manager.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
