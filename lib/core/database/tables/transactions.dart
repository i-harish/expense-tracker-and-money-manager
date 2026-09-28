import 'package:drift/drift.dart';
import 'accounts.dart';

enum TransactionType {
  income,
  expense,
  transfer,
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  TextColumn get type => textEnum<TransactionType>()();
  RealColumn get amount => real()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get transactionDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
