import 'package:drift/drift.dart';

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get period => text()(); // e.g. "2026-09"
  RealColumn get amount => real().withDefault(const Constant(9000.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
