import 'spend_store.dart';

/// In-memory SpendStore. Used by unit tests and as a safe fallback.
class MemoryStore implements SpendStore {
  SpendSnapshot _data = const SpendSnapshot(
    entries: [],
    categories: [],
    sources: [],
    recurring: [],
  );

  @override
  Future<SpendSnapshot> load() async => _data;

  @override
  Future<void> save(SpendSnapshot snapshot) async {
    _data = snapshot;
  }
}
