part of 'app_state.dart';

extension AppStateCsv on AppState {
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
}
