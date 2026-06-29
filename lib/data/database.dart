import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

@DataClassName('EntryRow')
class Entries extends Table {
  IntColumn get id => integer()();
  TextColumn get date => text()();
  TextColumn get type => text()();
  TextColumn get category => text()();
  TextColumn get title => text()();
  IntColumn get amount => integer()();
  IntColumn get splitTotal => integer().nullable()();
  IntColumn get splitCount => integer().nullable()();
  BoolColumn get recurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurEvery => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get key => text()();
  TextColumn get label => text()();
  IntColumn get color => integer()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('SourceRow')
class Sources extends Table {
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {name};
}

@DataClassName('RecurringRow')
class RecurringItems extends Table {
  IntColumn get id => integer()();
  TextColumn get type => text()();
  TextColumn get category => text()();
  TextColumn get title => text()();
  IntColumn get amount => integer()();
  TextColumn get freq => text()();
  TextColumn get anchor => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Entries, Categories, Sources, RecurringItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'spendwise'));

  @override
  int get schemaVersion => 1;
}
