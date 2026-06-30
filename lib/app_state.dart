import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart' hide Split;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'data/memory_store.dart';
import 'data/spend_store.dart';

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
    } catch (_) {/* ignore corrupt store */}
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
    } catch (_) {/* ignore corrupt legacy blob */}
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
    } catch (_) {}
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

  void setCurrency(String code) {
    final from = kCurrencies.firstWhere((c) => c.code == currencyCode);
    final to = kCurrencies.firstWhere((c) => c.code == code, orElse: () => from);
    if (from.code == to.code) {
      _commit(() => currencyCode = code);
      return;
    }
    final f = to.rate / from.rate;
    int cv(int n) {
      final v = (n * f).round();
      return v < 0 ? 0 : v;
    }

    _commit(() {
      currencyCode = code;
      transactions = transactions
          .map((t) => t.copyWith(
              amount: cv(t.amount),
              split: t.split == null
                  ? null
                  : Split(total: cv(t.split!.total), count: t.split!.count)))
          .toList();
      income = income.map((t) => t.copyWith(amount: cv(t.amount))).toList();
      recurring = recurring
          .map((r) => Recurring(id: r.id, type: r.type, category: r.category, title: r.title, amount: cv(r.amount)))
          .toList();
    });
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

  // ============================ CSV ============================
  String buildCsv() {
    final all = [...transactions, ...income];
    String esc(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    final rows = <List<Object?>>[
      ['date', 'type', 'category', 'title', 'amount', 'split_total', 'split_count', 'recurring', 'recur_every']
    ];
    for (final t in all) {
      rows.add([
        t.date,
        t.type,
        t.category,
        t.title,
        t.amount,
        t.split?.total ?? '',
        t.split?.count ?? '',
        t.recurring ? '1' : '',
        t.recurEvery ?? '',
      ]);
    }
    return rows.map((r) => r.map(esc).join(',')).join('\n');
  }

  List<String> parseCsvLine(String line) {
    final out = <String>[];
    var cur = '';
    var q = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (q) {
        if (ch == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            cur += '"';
            i++;
          } else {
            q = false;
          }
        } else {
          cur += ch;
        }
      } else {
        if (ch == '"') {
          q = true;
        } else if (ch == ',') {
          out.add(cur);
          cur = '';
        } else {
          cur += ch;
        }
      }
    }
    out.add(cur);
    return out;
  }

  /// Returns true on success (used to surface a snackbar).
  bool importCsv(String content) {
    try {
      final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
      if (lines.length <= 1) {
        _commit(() {
          transactions = [];
          income = [];
          entryOpen = false;
          screen = 'home';
        });
        return true;
      }
      lines.removeAt(0);
      final tx = <Txn>[];
      final inc = <Txn>[];
      for (var i = 0; i < lines.length; i++) {
        final c = parseCsvLine(lines[i]);
        String at(int idx) => idx < c.length ? c[idx] : '';
        final date = at(0).isEmpty ? iso(today) : at(0);
        final type = at(1);
        final category = at(2);
        final title = at(3);
        final amount = double.tryParse(at(4))?.round() ?? 0;
        final st = at(5);
        final sc = at(6);
        final recurringFlag = at(7) == '1';
        final every = at(8).isNotEmpty ? at(8) : (recurringFlag ? 'month' : null);
        if (type == 'income') {
          inc.add(Txn(id: _now() + i, date: date, type: 'income', category: category, title: title, amount: amount, recurring: recurringFlag, recurEvery: recurringFlag ? every : null));
        } else {
          tx.add(Txn(
            id: _now() + i,
            date: date,
            type: 'expense',
            category: category,
            title: title,
            amount: amount,
            split: st.isNotEmpty ? Split(total: double.tryParse(st)?.round() ?? 0, count: int.tryParse(sc) ?? 1) : null,
            recurring: recurringFlag,
            recurEvery: recurringFlag ? every : null,
          ));
        }
      }
      // Rebuild categories / sources / recurring templates from the imported
      // rows, since CSV only carries per-transaction data.
      final cats2 = <Category>[...kDefaultCats];
      final seenCat = cats2.map((c) => c.key.toLowerCase()).toSet();
      var pal = 0;
      for (final t in tx) {
        if (t.category.isNotEmpty && seenCat.add(t.category.toLowerCase())) {
          cats2.add(Category(
              key: t.category,
              label: t.category,
              color: kPalette[pal++ % kPalette.length]));
        }
      }
      final src2 = <String>[...kDefaultSources];
      final seenSrc = src2.map((s) => s.toLowerCase()).toSet();
      for (final t in inc) {
        if (t.category.isNotEmpty && seenSrc.add(t.category.toLowerCase())) {
          src2.add(t.category);
        }
      }
      final rec2 = <Recurring>[];
      final seenRec = <String>{};
      var recId = _now();
      for (final t in [...tx, ...inc]) {
        if (!t.recurring) continue;
        final k = '${t.type}|${t.category}|${t.title}';
        if (seenRec.add(k)) {
          rec2.add(Recurring(
              id: recId++,
              type: t.type,
              category: t.category,
              title: t.title,
              amount: t.amount,
              freq: t.recurEvery ?? 'month',
              anchor: t.date));
        }
      }
      _commit(() {
        transactions = tx;
        income = inc;
        cats = cats2;
        sources = src2;
        recurring = rec2;
        entryOpen = false;
        screen = 'home';
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================ derived views ============================
  List<Txn> sortDesc(List<Txn> arr) {
    final copy = [...arr];
    copy.sort((a, b) {
      if (a.date != b.date) return a.date.compareTo(b.date) < 0 ? 1 : -1;
      return b.id - a.id;
    });
    return copy;
  }

  List<Txn> get monthTx =>
      transactions.where((t) => monthKey(t.date) == viewMonth).toList();
  List<Txn> get monthInc =>
      income.where((t) => monthKey(t.date) == viewMonth).toList();

  int get monthIncome => monthInc.fold(0, (a, t) => a + t.amount);
  int get monthSpent => monthTx.fold(0, (a, t) => a + t.amount);

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get nameInitial {
    final t = name.trim();
    return t.isEmpty ? 'Y' : t[0].toUpperCase();
  }

  /// Number of expense entries dated exactly [isoDate] (for the calendar).
  int dayEntryCount(String isoDate) =>
      transactions.where((t) => t.date == isoDate).length;

  // ============================ insights aggregations ============================

  /// Expense breakdown by category for [mk] ('YYYY-MM'), sorted by amount desc.
  /// Returns an empty list when there are no expenses that month.
  List<CatSlice> categoryBreakdown(String mk) {
    final mtx = transactions.where((t) => monthKey(t.date) == mk).toList();
    if (mtx.isEmpty) return [];
    final agg = <String, int>{};
    for (final t in mtx) {
      agg[t.category] = (agg[t.category] ?? 0) + t.amount;
    }
    final total = agg.values.fold(0, (a, b) => a + b);
    if (total == 0) return [];
    return agg.entries.map((e) {
      final c = catOf(e.key);
      return CatSlice(
          key: e.key, label: c.label, color: c.color,
          amount: e.value, pct: e.value / total);
    }).toList()
      ..sort((a, b) => b.amount - a.amount);
  }

  /// Income vs spent for the trailing [months] calendar months ending at
  /// [viewMonth], returned oldest-first.
  List<MonthTotals> monthlyTotals({int months = 6}) {
    final p = viewMonth.split('-').map(int.parse).toList();
    return List.generate(months, (i) {
      final d = DateTime(p[0], p[1] - (months - 1 - i), 1);
      final mk = '${d.year}-${_pad(d.month)}';
      final inc = income
          .where((t) => monthKey(t.date) == mk)
          .fold(0, (a, t) => a + t.amount);
      final spent = transactions
          .where((t) => monthKey(t.date) == mk)
          .fold(0, (a, t) => a + t.amount);
      return MonthTotals(
          monthKey: mk, label: kMon[d.month - 1], income: inc, spent: spent);
    });
  }

  /// Daily expense totals for [mk]. Result length == days in that month;
  /// index 0 = day 1. Zero for days with no spending.
  List<int> dailyTotals(String mk) {
    final p = mk.split('-').map(int.parse).toList();
    final daysInMonth = DateTime(p[0], p[1] + 1, 0).day;
    final result = List<int>.filled(daysInMonth, 0);
    for (final t in transactions) {
      if (monthKey(t.date) == mk) {
        final day = int.parse(t.date.split('-')[2]);
        if (day >= 1 && day <= daysInMonth) result[day - 1] += t.amount;
      }
    }
    return result;
  }

  /// Derived stats for [mk]: savings rate, avg/day, biggest expense,
  /// previous month spent, and delta %.
  InsightStats insightStats(String mk) {
    final mtx = transactions.where((t) => monthKey(t.date) == mk).toList();
    final minc = income.where((t) => monthKey(t.date) == mk).toList();
    final spent = mtx.fold(0, (a, t) => a + t.amount);
    final inc = minc.fold(0, (a, t) => a + t.amount);
    final savingsRate = inc > 0 ? (inc - spent) / inc : 0.0;

    final p = mk.split('-').map(int.parse).toList();
    final now = DateTime.now();
    final isCurrent = p[0] == now.year && p[1] == now.month;
    final daysElapsed = isCurrent ? now.day : DateTime(p[0], p[1] + 1, 0).day;
    final avgPerDay = daysElapsed > 0 ? spent ~/ daysElapsed : 0;

    final biggestExpense =
        mtx.isEmpty ? 0 : mtx.map((t) => t.amount).reduce(math.max);

    final prevD = DateTime(p[0], p[1] - 1, 1);
    final prevMk = '${prevD.year}-${_pad(prevD.month)}';
    final prevSpent = transactions
        .where((t) => monthKey(t.date) == prevMk)
        .fold(0, (a, t) => a + t.amount);
    final deltaPct =
        prevSpent > 0 ? (spent - prevSpent) / prevSpent : 0.0;

    return InsightStats(
      savingsRate: savingsRate,
      avgPerDay: avgPerDay,
      biggestExpense: biggestExpense,
      prevMonthSpent: prevSpent,
      deltaPct: deltaPct,
    );
  }
}
