import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart' hide Split;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'data/memory_store.dart';
import 'data/spend_store.dart';
import 'data/snapshot_store.dart';

part 'app_state_insights.dart';
part 'app_state_csv.dart';

const _storeKey = 'exptrack_v3';

const kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];
const kMon = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

const kPalette = [
  Color(0xFFE0533D), Color(0xFF2A6FDB), Color(0xFF7C3AED), Color(0xFF1F8A5B),
  Color(0xFFD98A1F), Color(0xFF5A6B7B), Color(0xFFC2497A), Color(0xFF0E9488),
];

final kDefaultCats = <Category>[
  const Category(key: 'Food', label: 'Food', color: Color(0xFFE0533D)),
  const Category(key: 'Transport', label: 'Transport', color: Color(0xFF2A6FDB)),
  const Category(key: 'Shopping', label: 'Shopping', color: Color(0xFFD98A1F)),
  const Category(key: 'Bills', label: 'Bills', color: Color(0xFF5A6B7B)),
  const Category(key: 'Health', label: 'Health', color: Color(0xFF1F8A5B)),
  const Category(key: 'Other', label: 'Other', color: Color(0xFF8A8A82)),
];

const kDefaultSources = <String>['Salary', 'Other'];

/// Recurrence intervals and their display strings.
const kFreqs = <String>['day', 'week', 'month', 'year'];
const kFreqAdverb = <String, String>{
  'day': 'daily',
  'week': 'weekly',
  'month': 'monthly',
  'year': 'yearly'
};
const kFreqShort = <String, String>{
  'day': '/day',
  'week': '/wk',
  'month': '/mo',
  'year': '/yr'
};
const kFreqLabel = <String, String>{
  'day': 'Day',
  'week': 'Week',
  'month': 'Month',
  'year': 'Year'
};

const kCurrencies = <Currency>[
  Currency(code: 'INR', symbol: '₹', locale: 'en_IN', label: 'Indian Rupee', rate: 1),
  Currency(code: 'USD', symbol: '\$', locale: 'en_US', label: 'US Dollar', rate: 0.012),
  Currency(code: 'EUR', symbol: '€', locale: 'de_DE', label: 'Euro', rate: 0.011),
  Currency(code: 'GBP', symbol: '£', locale: 'en_GB', label: 'British Pound', rate: 0.0095),
  Currency(code: 'JPY', symbol: '¥', locale: 'ja_JP', label: 'Japanese Yen', rate: 1.85),
  Currency(code: 'AED', symbol: 'د.إ', locale: 'en_AE', label: 'UAE Dirham', rate: 0.044),
];

/// Holds every piece of mutable app state and the full business logic, ported
/// 1:1 from the prototype's `DCLogic` class.
class AppState extends ChangeNotifier {
  final SpendStore store;
  final SnapshotStore _snapshots = SnapshotStore();

  AppState({SpendStore? store}) : store = store ?? MemoryStore() {
    final now = _stripTime(DateTime.now());
    today = now;
    viewMonth = monthKey(iso(now));
    // New users start empty — default categories + sources are kept (below) so
    // the app is usable immediately, but no fake transactions/income/recurring.
    transactions = [];
    income = [];
    recurring = [];
    entryDate = iso(today);
  }

  /// Injects the original prototype demo dataset on demand (Settings → Load
  /// sample data). Not called on boot.
  void loadSampleData() {
    String d(int n) => isoOffset(n);
    _commit(() {
      transactions = [
        Txn(id: 1, date: d(0), type: 'expense', category: 'Travel', title: 'Metro to college', amount: 40),
        Txn(id: 2, date: d(0), type: 'expense', category: 'Food', title: 'Fried rice lunch', amount: 100, split: const Split(total: 400, count: 4)),
        Txn(id: 3, date: d(1), type: 'expense', category: 'AI Subs', title: 'ChatGPT Plus', amount: 1650, recurring: true),
        Txn(id: 4, date: d(1), type: 'expense', category: 'Entertainment', title: 'Movie ticket', amount: 250),
        Txn(id: 5, date: d(3), type: 'expense', category: 'Shopping', title: 'Groceries', amount: 480),
        Txn(id: 6, date: d(3), type: 'expense', category: 'Travel', title: 'Metro home', amount: 40),
        Txn(id: 7, date: d(4), type: 'expense', category: 'Food', title: 'Group lunch', amount: 120, split: const Split(total: 480, count: 4)),
        Txn(id: 8, date: d(5), type: 'expense', category: 'Education', title: 'Notebooks', amount: 90),
      ];
      income = [
        Txn(id: 101, date: d(12), type: 'income', category: 'Freelance', title: 'Freelance project', amount: 3500),
        Txn(id: 102, date: d(22), type: 'income', category: 'Pocket money', title: 'From parents', amount: 5000),
        Txn(id: 103, date: d(26), type: 'income', category: 'Salary', title: 'Monthly salary', amount: 18000, recurring: true),
      ];
      recurring = [
        const Recurring(id: 301, type: 'expense', category: 'AI Subs', title: 'ChatGPT Plus', amount: 1650),
        const Recurring(id: 302, type: 'income', category: 'Salary', title: 'Monthly salary', amount: 18000),
      ];
      screen = 'home';
    });
  }

  // ---- navigation / ui state
  String screen = 'home';
  bool entryOpen = false;
  Txn? detailTxn; // non-null while the read-only detail sheet is open
  String entryMode = 'expense';
  int? editingId;

  // ---- entry form state
  String amount = '0';
  String cat = 'Food';
  String source = 'Salary';
  String note = '';
  late String entryDate;
  bool splitOn = false;
  int splitCount = 4;
  bool recurringOn = false;
  String recurEverySel = 'month'; // selected interval for the entry form

  // ---- preferences
  String themeMode = 'system'; // 'system' | 'light' | 'dark'
  String currencyCode = 'INR';
  String name = '';
  bool onboardingComplete = false;
  String? lastBackup;

  // which Insights cards are visible (default all on)
  final Map<String, bool> insightCards = {
    'summary': true,
    'category': true,
    'trend': true,
    'daily': true,
    'calendar': true,
  };
  bool insightOn(String key) => insightCards[key] ?? true;
  void toggleInsight(String key) {
    insightCards[key] = !insightOn(key);
    _savePrefs();
    notifyListeners();
  }

  ThemeMode get materialThemeMode => switch (themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  // ---- browsing state
  late String viewMonth;
  String histQuery = '';
  String histCat = 'All';
  String newCatName = '';
  Color newCatColor = const Color(0xFFE0533D);
  String newSourceName = '';

  // ---- data
  List<Category> cats = kDefaultCats.map((c) => c).toList();
  List<String> sources = List<String>.from(kDefaultSources);
  late List<Txn> transactions;
  late List<Txn> income;
  late List<Recurring> recurring;

  late final DateTime today;

  // ============================ persistence ============================
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // one-time migration from the legacy JSON blob
      if (prefs.getBool('drift_migrated') != true) {
        await _migrateLegacy(prefs);
        await prefs.setBool('drift_migrated', true);
      }

      // data from the store
      final snap = await store.load();
      transactions = snap.entries.where((t) => t.type == 'expense').toList();
      income = snap.entries.where((t) => t.type == 'income').toList();
      if (snap.categories.isNotEmpty) cats = snap.categories;
      if (snap.sources.isNotEmpty) sources = snap.sources;
      recurring = snap.recurring;

      // scalar prefs
      final cur = prefs.getString('pref_currency');
      if (cur != null) currencyCode = cur;
      final th = prefs.getString('pref_theme');
      if (th != null) themeMode = (th == 'light' || th == 'dark') ? th : 'system';
      final nm = prefs.getString('pref_name');
      if (nm != null) name = nm;
      if (prefs.getBool('pref_onboarded') == true) onboardingComplete = true;
      final ic = prefs.getString('insight_cards');
      if (ic != null) {
        try {
          final m = (jsonDecode(ic) as Map).cast<String, dynamic>();
          for (final k in insightCards.keys.toList()) {
            if (m[k] is bool) insightCards[k] = m[k] as bool;
          }
        } catch (_) {}
      }
      lastBackup = prefs.getString('pref_last_backup');
    } catch (e) {
      if (kDebugMode) debugPrint('SpendWise persistence: $e');
    }
    _applyRecurring(); // post any occurrences due since the last open
    notifyListeners();
  }

  /// One-time import of the pre-Drift `exptrack_v3` JSON blob. Writes data
  /// through the store and prefs through their new keys. Non-destructive: the
  /// legacy blob is left in place as a backup.
  Future<void> _migrateLegacy(SharedPreferences prefs) async {
    try {
      final raw = prefs.getString(_storeKey);
      if (raw == null) return;
      final d = jsonDecode(raw) as Map<String, dynamic>;
      final entries = <Txn>[];
      if (d['transactions'] is List) {
        entries.addAll((d['transactions'] as List)
            .map((e) => Txn.fromJson((e as Map).cast<String, dynamic>())));
      }
      if (d['income'] is List) {
        entries.addAll((d['income'] as List)
            .map((e) => Txn.fromJson((e as Map).cast<String, dynamic>())));
      }
      final cats2 = d['cats'] is List
          ? (d['cats'] as List)
              .map((e) => Category.fromJson((e as Map).cast<String, dynamic>()))
              .toList()
          : kDefaultCats.map((c) => c).toList();
      final src2 = d['sources'] is List
          ? (d['sources'] as List).map((e) => e.toString()).toList()
          : List<String>.from(kDefaultSources);
      final rec2 = d['recurring'] is List
          ? (d['recurring'] as List)
              .map((e) => Recurring.fromJson((e as Map).cast<String, dynamic>()))
              .toList()
          : <Recurring>[];
      await store.save(SpendSnapshot(
          entries: entries, categories: cats2, sources: src2, recurring: rec2));

      if (d['currency'] is String) {
        await prefs.setString('pref_currency', d['currency'] as String);
      }
      if (d['theme'] is String) {
        final t = d['theme'] as String;
        await prefs.setString('pref_theme', (t == 'light' || t == 'dark') ? t : 'system');
      }
      if (d['name'] is String) {
        await prefs.setString('pref_name', d['name'] as String);
      }
      if (d['onboarded'] == true) {
        await prefs.setBool('pref_onboarded', true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SpendWise persistence: $e');
    }
  }

  Future<void>? _pendingSave;

  void _persist() {
    // fire-and-forget; the store serializes overlapping writes. We keep a
    // handle to the latest write so flush() can await it before app exit.
    _pendingSave = store.save(SpendSnapshot(
      entries: [...transactions, ...income],
      categories: cats,
      sources: sources,
      recurring: recurring,
    ));
  }

  /// Awaits the most recent in-flight write. Call this from a lifecycle
  /// observer (app paused/detached) so the last mutation before exit isn't
  /// lost if the process is killed while a write is still in flight.
  Future<void> flush() async {
    await _pendingSave;
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pref_currency', currencyCode);
      await prefs.setString('pref_theme', themeMode);
      await prefs.setString('pref_name', name);
      await prefs.setBool('pref_onboarded', onboardingComplete);
      await prefs.setString('insight_cards', jsonEncode(insightCards));
      if (lastBackup != null) {
        await prefs.setString('pref_last_backup', lastBackup!);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SpendWise persistence: $e');
    }
  }

  /// Marks first-run setup complete and stores the chosen preferences.
  void completeOnboarding({
    required String name,
    required String currencyCode,
    required String themeMode,
  }) =>
      _commit(() {
        this.name = name.trim().isEmpty ? 'You' : name.trim();
        this.currencyCode = currencyCode;
        this.themeMode = themeMode;
        onboardingComplete = true;
        screen = 'home';
      });

  /// Wipes all data + preferences and returns the user to onboarding.
  Future<void> resetAll() async {
    transactions = [];
    income = [];
    recurring = [];
    cats = kDefaultCats.map((c) => c).toList();
    sources = List<String>.from(kDefaultSources);
    name = '';
    currencyCode = 'INR';
    themeMode = 'system';
    onboardingComplete = false;
    screen = 'home';
    await store.save(SpendSnapshot(
        entries: const [], categories: cats, sources: sources, recurring: const []));
    await _savePrefs();
    notifyListeners();
  }

  /// Full, lossless snapshot for JSON backup (same shape as the legacy blob).
  Map<String, dynamic> backupMap() => {
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'income': income.map((t) => t.toJson()).toList(),
        'cats': cats.map((c) => c.toJson()).toList(),
        'sources': sources,
        'recurring': recurring.map((r) => r.toJson()).toList(),
        'currency': currencyCode,
        'theme': themeMode,
        'name': name,
      };

  /// Replaces all data + prefs from a backup map (type-guarded per field).
  void restoreFromBackup(Map<String, dynamic> d) {
    List<Txn> txns(String k) => d[k] is List
        ? (d[k] as List)
            .map((e) => Txn.fromJson((e as Map).cast<String, dynamic>()))
            .toList()
        : <Txn>[];
    _commit(() {
      transactions = txns('transactions');
      income = txns('income');
      if (d['cats'] is List) {
        cats = (d['cats'] as List)
            .map((e) => Category.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
      if (d['sources'] is List) {
        sources = (d['sources'] as List).map((e) => e.toString()).toList();
      }
      if (d['recurring'] is List) {
        recurring = (d['recurring'] as List)
            .map((e) => Recurring.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
      if (d['currency'] is String) currencyCode = d['currency'] as String;
      if (d['theme'] is String) {
        final t = d['theme'] as String;
        themeMode = (t == 'light' || t == 'dark') ? t : 'system';
      }
      if (d['name'] is String) name = d['name'] as String;
      screen = 'home';
    });
  }

  /// Records that a backup export just happened (drives the reminder).
  void markBackedUp() {
    lastBackup = DateTime.now().toIso8601String();
    _savePrefs();
    notifyListeners();
  }

  /// Writes one deduped local snapshot of the current state. Called from the
  /// app-background lifecycle hook. Non-fatal: failures are swallowed by the
  /// store, so this never throws.
  Future<void> writeAutoSnapshot() => _snapshots.write(backupMap());

  /// Apply a mutation, persist, and notify listeners — the equivalent of the
  /// prototype's setState + componentDidUpdate.
  void _commit(VoidCallback mutate) {
    mutate();
    _persist();
    _savePrefs();
    notifyListeners();
  }

  // ============================ date helpers ============================
  static DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);
  String _pad(int n) => n.toString().padLeft(2, '0');
  String iso(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
  String isoOffset(int n) => iso(today.subtract(Duration(days: n)));
  DateTime parse(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  String monthKey(String s) => s.substring(0, 7);
  String monthName(String key) {
    final p = key.split('-');
    return '${kMonths[int.parse(p[1]) - 1]} ${p[0]}';
  }

  String dateLabel(String s) {
    final d = parse(s);
    final diff = today
            .difference(DateTime(d.year, d.month, d.day))
            .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    var str = '${d.day} ${kMon[d.month - 1]}';
    if (d.year != today.year) str += ' ${d.year}';
    return str;
  }

  // ============================ money helpers ============================
  Currency get currency =>
      kCurrencies.firstWhere((c) => c.code == currencyCode, orElse: () => kCurrencies[0]);

  NumberFormat _nf() {
    try {
      return NumberFormat.decimalPattern(currency.locale);
    } catch (_) {
      return NumberFormat.decimalPattern('en_US');
    }
  }

  String fmt(num n) => currency.symbol + _nf().format(n.round());

  /// Formats the in-progress keypad string, preserving the typed decimal part.
  String fmtType(String str) {
    if (str.isEmpty) return '0';
    final p = str.split('.');
    final gi = _nf().format(int.tryParse(p[0].isEmpty ? '0' : p[0]) ?? 0);
    return p.length > 1 ? '$gi.${p[1]}' : gi;
  }

  Category catOf(String key) => cats.firstWhere(
        (c) => c.key == key,
        orElse: () => Category(key: key, label: key, color: const Color(0xFF8A8A82)),
      );

  // ============================ actions ============================
  void shiftMonth(int delta) {
    // viewMonth months are 1-based (e.g. '2026-06'); DateTime months are also
    // 1-based, so add delta directly — DateTime normalises year rollover.
    final p = viewMonth.split('-').map(int.parse).toList();
    final d = DateTime(p[0], p[1] + delta, 1);
    _commit(() => viewMonth = '${d.year}-${_pad(d.month)}');
  }

  void go(String s) => _commit(() => screen = s);

  void openEntry(String mode, bool split) => _commit(() {
        entryOpen = true;
        entryMode = mode;
        editingId = null;
        splitOn = split;
        recurringOn = false;
        recurEverySel = 'month';
        amount = '0';
        note = '';
        entryDate = iso(today);
        cat = cats.isNotEmpty ? cats.first.key : 'Other';
        source = sources.isNotEmpty ? sources.first : '';
      });

  void openEdit(Txn t) => _commit(() {
        final isInc = t.isIncome;
        entryOpen = true;
        entryMode = isInc ? 'income' : 'expense';
        editingId = t.id;
        amount = (t.split != null ? t.split!.total : t.amount).toString();
        if (isInc) {
          source = t.category;
        } else {
          cat = t.category;
        }
        note = t.title;
        entryDate = t.date;
        splitOn = t.split != null;
        splitCount = t.split != null ? t.split!.count : 4;
        recurringOn = t.recurring;
        recurEverySel = t.recurEvery ?? 'month';
      });

  void close() => _commit(() {
        entryOpen = false;
        editingId = null;
      });

  /// Opens the read-only transaction detail sheet.
  void openDetail(Txn t) => _commit(() => detailTxn = t);
  void closeDetail() => _commit(() => detailTxn = null);

  /// From the detail sheet's "Edit" button: close detail and open the editor.
  void editFromDetail() {
    final t = detailTxn;
    if (t == null) return;
    detailTxn = null;
    openEdit(t);
  }

  void press(String d) => _commit(() {
        var a = amount;
        if (d == 'back') {
          a = a.length <= 1 ? '0' : a.substring(0, a.length - 1);
          if (a.isEmpty || a == '.') a = '0';
          amount = a;
          return;
        }
        if (d == '.') {
          if (a.contains('.')) return;
          amount = '$a.';
          return;
        }
        if (a == '0') {
          a = d;
        } else {
          a = a + d;
        }
        if (a.replaceAll('.', '').length > 9) return;
        amount = a;
      });

  int _lastNow = 0;
  int _now() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    _lastNow = ms > _lastNow ? ms : _lastNow + 1;
    return _lastNow;
  }

  void save() {
    final val = double.tryParse(amount) ?? 0;
    if (val <= 0) return;
    final id = editingId ?? _now();
    Txn row;
    final every = recurringOn ? recurEverySel : null;
    if (entryMode == 'income') {
      row = Txn(
        id: id,
        date: entryDate,
        type: 'income',
        category: source,
        title: note.isNotEmpty ? note : source,
        amount: val.round(),
        recurring: recurringOn,
        recurEvery: every,
      );
    } else {
      final count = splitCount < 1 ? 1 : splitCount;
      final rec = splitOn ? (val / count).round() : val.round();
      if (rec <= 0) return;
      final c = catOf(cat);
      row = Txn(
        id: id,
        date: entryDate,
        type: 'expense',
        category: cat,
        title: note.isNotEmpty ? note : c.label,
        amount: rec,
        split: splitOn ? Split(total: val.round(), count: count) : null,
        recurring: recurringOn,
        recurEvery: every,
      );
    }
    _commit(() {
      transactions = transactions.where((t) => t.id != id).toList();
      income = income.where((t) => t.id != id).toList();
      if (row.isIncome) {
        income = [row, ...income];
      } else {
        transactions = [row, ...transactions];
      }
      if (recurringOn) {
        final exists = recurring.any((r) =>
            r.title == row.title && r.category == row.category && r.type == row.type);
        if (!exists) {
          recurring = [
            ...recurring,
            Recurring(
                id: _now() + 1,
                type: row.type,
                category: row.category,
                title: row.title,
                amount: row.amount,
                freq: recurEverySel,
                anchor: row.date),
          ];
        }
      }
      entryOpen = false;
      editingId = null;
      amount = '0';
      note = '';
      splitOn = false;
      recurringOn = false;
      saveTick = true; // trigger the success-tick overlay
    });
  }

  /// True for the brief moment after a successful save; drives the GPay-style
  /// success tick overlay. Transient UI state (not persisted).
  bool saveTick = false;
  void dismissTick() {
    saveTick = false;
    notifyListeners();
  }

  /// The entry currently being edited, if any (used to support undo on delete).
  Txn? get editingTxn {
    final id = editingId;
    if (id == null) return null;
    for (final t in transactions) {
      if (t.id == id) return t;
    }
    for (final t in income) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Deletes a specific entry (used by the detail sheet) and closes it.
  void removeTxn(Txn t) => _commit(() {
        transactions = transactions.where((x) => x.id != t.id).toList();
        income = income.where((x) => x.id != t.id).toList();
        detailTxn = null;
      });

  void remove() {
    final id = editingId;
    if (id == null) return;
    _commit(() {
      transactions = transactions.where((t) => t.id != id).toList();
      income = income.where((t) => t.id != id).toList();
      entryOpen = false;
      editingId = null;
    });
  }

  /// Re-inserts a previously removed entry (the Undo action).
  void restore(Txn t) => _commit(() {
        if (t.isIncome) {
          income = [t, ...income];
        } else {
          transactions = [t, ...transactions];
        }
      });

  void logRecurring(Recurring r) {
    final today_ = iso(today);
    final row = Txn(
      id: _now(),
      date: today_,
      type: r.type,
      category: r.category,
      title: r.title,
      amount: r.amount,
      recurring: true,
      recurEvery: r.freq,
    );
    _commit(() {
      if (r.type == 'income') {
        income = [row, ...income];
      } else {
        transactions = [row, ...transactions];
      }
      // logging counts as this period's occurrence
      recurring = recurring
          .map((x) => x.id == r.id ? x.copyWith(anchor: today_) : x)
          .toList();
      screen = 'home';
    });
  }

  void delRecurring(int id) =>
      _commit(() => recurring = recurring.where((r) => r.id != id).toList());

  // ---- auto-posting of recurring entries -------------------------------
  /// Returns the ISO date one [freq] interval after [isoDate].
  String _advance(String isoDate, String freq) {
    final d = parse(isoDate);
    final next = switch (freq) {
      'day' => d.add(const Duration(days: 1)),
      'week' => d.add(const Duration(days: 7)),
      'year' => DateTime(d.year + 1, d.month, d.day),
      _ => DateTime(d.year, d.month + 1, d.day), // month
    };
    return iso(next);
  }

  /// Posts any recurring occurrences that have come due since each template's
  /// last anchor, up to today. Called once on app open (from [load]).
  void _applyRecurring() {
    final todayIso = iso(today);
    final addedTx = <Txn>[];
    final addedInc = <Txn>[];
    var idSeed = _now();
    final updated = recurring.map((r) {
      var anchor = r.anchor.isEmpty ? todayIso : r.anchor;
      var guard = 0;
      var next = _advance(anchor, r.freq);
      while (next.compareTo(todayIso) <= 0 && guard < 500) {
        final row = Txn(
          id: idSeed++,
          date: next,
          type: r.type,
          category: r.category,
          title: r.title,
          amount: r.amount,
          recurring: true,
          recurEvery: r.freq,
        );
        if (r.type == 'income') {
          addedInc.add(row);
        } else {
          addedTx.add(row);
        }
        anchor = next;
        next = _advance(anchor, r.freq);
        guard++;
      }
      return r.copyWith(anchor: anchor);
    }).toList();
    recurring = updated;
    if (addedTx.isNotEmpty || addedInc.isNotEmpty) {
      transactions = [...addedTx, ...transactions];
      income = [...addedInc, ...income];
      _persist();
    }
  }

  /// Currency is display-only: switching changes the symbol/format used by
  /// [fmt], it never rewrites stored amounts.
  void setCurrency(String code) => _commit(() => currencyCode = code);

  /// First palette colour not already used by a category (fallback: first).
  Color firstUnusedCatColor() {
    final used = cats.map((c) => c.color.toARGB32()).toSet();
    for (final col in kPalette) {
      if (!used.contains(col.toARGB32())) return col;
    }
    return kPalette.first;
  }

  void addCat() {
    final n = newCatName.trim();
    if (n.isEmpty) return;
    if (cats.any((c) => c.key.toLowerCase() == n.toLowerCase())) {
      _commit(() => newCatName = '');
      return;
    }
    _commit(() {
      cats = [...cats, Category(key: n, label: n, color: newCatColor)];
      newCatName = '';
      newCatColor = firstUnusedCatColor();
    });
  }

  void delCat(String key) => _commit(() {
        cats = cats.where((c) => c.key != key).toList();
        if (cat == key) cat = cats.isNotEmpty ? cats.first.key : 'Other';
      });

  void addSource() {
    final n = newSourceName.trim();
    if (n.isEmpty) return;
    if (sources.any((x) => x.toLowerCase() == n.toLowerCase())) {
      _commit(() => newSourceName = '');
      return;
    }
    _commit(() {
      sources = [...sources, n];
      newSourceName = '';
    });
  }

  void delSource(String name) => _commit(() {
        sources = sources.where((x) => x != name).toList();
        if (source == name) source = sources.isNotEmpty ? sources.first : '';
      });

  // ---- simple field setters used by inputs / chips
  void set(VoidCallback mutate) => _commit(mutate);

  String get nameInitial {
    final t = name.trim();
    return t.isEmpty ? 'Y' : t[0].toUpperCase();
  }
}
