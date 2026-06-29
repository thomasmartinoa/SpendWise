import 'database.dart';
import 'mappers.dart';
import 'spend_store.dart';

/// SpendStore backed by SQLite. `save` replaces all four tables in a single
/// transaction (snapshot semantics) and serializes overlapping writes so a
/// slower write can never clobber a newer snapshot.
class DriftStore implements SpendStore {
  final AppDatabase db;
  DriftStore(this.db);

  bool _writing = false;
  SpendSnapshot? _pending;

  @override
  Future<SpendSnapshot> load() async {
    final entries = await db.select(db.entries).get();
    final cats = await db.select(db.categories).get();
    final srcs = await db.select(db.sources).get();
    final recs = await db.select(db.recurringItems).get();
    return SpendSnapshot(
      entries: entries.map(entryRowToTxn).toList(),
      categories: cats.map(categoryRowToCategory).toList(),
      sources: srcs.map((s) => s.name).toList(),
      recurring: recs.map(recurringRowToRecurring).toList(),
    );
  }

  @override
  Future<void> save(SpendSnapshot snapshot) async {
    _pending = snapshot;
    if (_writing) return; // an in-flight write will pick up _pending
    _writing = true;
    try {
      while (_pending != null) {
        final snap = _pending!;
        _pending = null;
        await db.transaction(() async {
          await db.delete(db.entries).go();
          await db.delete(db.categories).go();
          await db.delete(db.sources).go();
          await db.delete(db.recurringItems).go();
          await db.batch((b) {
            b.insertAll(db.entries, snap.entries.map(txnToEntryCompanion).toList());
            b.insertAll(db.categories, snap.categories.map(categoryToCompanion).toList());
            b.insertAll(db.sources,
                snap.sources.map((s) => SourcesCompanion.insert(name: s)).toList());
            b.insertAll(db.recurringItems,
                snap.recurring.map(recurringToCompanion).toList());
          });
        });
      }
    } finally {
      _writing = false;
    }
  }
}
