import '../models.dart';

/// A complete snapshot of the app's relational data (everything except the
/// scalar preferences, which live in shared_preferences). `entries` holds both
/// expenses and income — the `type` field distinguishes them.
class SpendSnapshot {
  final List<Txn> entries;
  final List<Category> categories;
  final List<String> sources;
  final List<Recurring> recurring;
  const SpendSnapshot({
    required this.entries,
    required this.categories,
    required this.sources,
    required this.recurring,
  });
}

/// Persistence boundary. Implemented by DriftStore (production) and
/// MemoryStore (tests / fallback).
abstract class SpendStore {
  Future<SpendSnapshot> load();
  Future<void> save(SpendSnapshot snapshot);
}
