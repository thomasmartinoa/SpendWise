import 'dart:convert';
import 'package:flutter/material.dart' hide Split;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

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
  AppState() {
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

  // ---- preferences
  String themeMode = 'system'; // 'system' | 'light' | 'dark'
  String currencyCode = 'INR';
  String name = '';
  bool onboardingComplete = false;

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
      final raw = prefs.getString(_storeKey);
      if (raw == null) return;
      final d = jsonDecode(raw) as Map<String, dynamic>;
      bool dated(dynamic a) =>
          a is List && a.every((t) => t is Map && t['date'] is String);
      if (dated(d['transactions'])) {
        transactions = (d['transactions'] as List)
            .map((e) => Txn.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
      if (dated(d['income'])) {
        income = (d['income'] as List)
            .map((e) => Txn.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
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
      if (d['currency'] != null) currencyCode = d['currency'] as String;
      // 'theme' is now 'system'|'light'|'dark'; legacy 'light'/'dark' migrate
      // as-is, anything else falls back to 'system'.
      if (d['theme'] is String) {
        final t = d['theme'] as String;
        themeMode = (t == 'light' || t == 'dark') ? t : 'system';
      }
      if (d['name'] != null) name = d['name'] as String;
      if (d['onboarded'] == true) onboardingComplete = true;
    } catch (_) {/* ignore corrupt store */}
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storeKey,
        jsonEncode({
          'transactions': transactions.map((t) => t.toJson()).toList(),
          'income': income.map((t) => t.toJson()).toList(),
          'cats': cats.map((c) => c.toJson()).toList(),
          'sources': sources,
          'recurring': recurring.map((r) => r.toJson()).toList(),
          'currency': currencyCode,
          'theme': themeMode,
          'name': name,
          'onboarded': onboardingComplete,
        }),
      );
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storeKey);
    } catch (_) {}
    notifyListeners();
  }

  /// Apply a mutation, persist, and notify listeners — the equivalent of the
  /// prototype's setState + componentDidUpdate.
  void _commit(VoidCallback mutate) {
    mutate();
    _persist();
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

  int _now() => DateTime.now().millisecondsSinceEpoch;

  void save() {
    final val = double.tryParse(amount) ?? 0;
    if (val <= 0) return;
    final id = editingId ?? _now();
    Txn row;
    if (entryMode == 'income') {
      row = Txn(
        id: id,
        date: entryDate,
        type: 'income',
        category: source,
        title: note.isNotEmpty ? note : source,
        amount: val.round(),
        recurring: recurringOn,
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
            Recurring(id: _now() + 1, type: row.type, category: row.category, title: row.title, amount: row.amount),
          ];
        }
      }
      entryOpen = false;
      editingId = null;
      amount = '0';
      note = '';
      splitOn = false;
      recurringOn = false;
    });
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
    final id = _now();
    final row = Txn(
      id: id,
      date: iso(today),
      type: r.type,
      category: r.category,
      title: r.title,
      amount: r.amount,
    );
    _commit(() {
      if (r.type == 'income') {
        income = [row, ...income];
      } else {
        transactions = [row, ...transactions];
      }
      screen = 'home';
    });
  }

  void delRecurring(int id) =>
      _commit(() => recurring = recurring.where((r) => r.id != id).toList());

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
      ['date', 'type', 'category', 'title', 'amount', 'split_total', 'split_count', 'recurring']
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
        if (type == 'income') {
          inc.add(Txn(id: _now() + i, date: date, type: 'income', category: category, title: title, amount: amount, recurring: recurringFlag));
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
          ));
        }
      }
      _commit(() {
        transactions = tx;
        income = inc;
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
}
