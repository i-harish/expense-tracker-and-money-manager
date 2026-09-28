import 'package:drift/drift.dart';

class CreditCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get lastFourDigits => text().withLength(min: 4, max: 4)();
  RealColumn get creditLimit => real()();
  RealColumn get outstandingBalance => real().withDefault(const Constant(0.0))();
  IntColumn get billingCycleDay => integer().nullable()();
  IntColumn get paymentDueDay => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
