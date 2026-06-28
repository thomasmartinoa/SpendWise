import 'package:flutter/material.dart';

/// An expense category. `key` is the stable id, `label` the display name.
class Category {
  final String key;
  final String label;
  final Color color;
  const Category({required this.key, required this.label, required this.color});

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'color': color.toARGB32(),
      };

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        key: j['key'] as String,
        label: (j['label'] ?? j['key']) as String,
        color: Color(_colorFrom(j['color'])),
      );
}

/// A supported currency with its indicative conversion rate (relative to INR).
class Currency {
  final String code;
  final String symbol;
  final String locale; // intl locale tag, e.g. en_IN
  final String label;
  final double rate;
  const Currency({
    required this.code,
    required this.symbol,
    required this.locale,
    required this.label,
    required this.rate,
  });
}

/// Optional split-bill detail attached to an expense.
class Split {
  final int total;
  final int count;
  const Split({required this.total, required this.count});

  Map<String, dynamic> toJson() => {'total': total, 'count': count};
  factory Split.fromJson(Map<String, dynamic> j) =>
      Split(total: (j['total'] as num).round(), count: (j['count'] as num).toInt());
}

/// A single income or expense entry.
class Txn {
  final int id;
  final String date; // YYYY-MM-DD
  final String type; // 'expense' | 'income'
  final String category; // category key, or income source name
  final String title;
  final int amount;
  final Split? split;
  final bool recurring;
  final String? recurEvery; // 'day' | 'week' | 'month' | 'year' when recurring

  const Txn({
    required this.id,
    required this.date,
    required this.type,
    required this.category,
    required this.title,
    required this.amount,
    this.split,
    this.recurring = false,
    this.recurEvery,
  });

  bool get isIncome => type == 'income';

  Txn copyWith({int? amount, Split? split, bool clearSplit = false}) => Txn(
        id: id,
        date: date,
        type: type,
        category: category,
        title: title,
        amount: amount ?? this.amount,
        split: clearSplit ? null : (split ?? this.split),
        recurring: recurring,
        recurEvery: recurEvery,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'type': type,
        'category': category,
        'title': title,
        'amount': amount,
        'split': split?.toJson(),
        'recurring': recurring,
        'recurEvery': recurEvery,
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: (j['id'] as num).toInt(),
        date: j['date'] as String,
        type: j['type'] as String,
        category: j['category'] as String,
        title: (j['title'] ?? '') as String,
        amount: (j['amount'] as num).round(),
        split: j['split'] == null
            ? null
            : Split.fromJson((j['split'] as Map).cast<String, dynamic>()),
        recurring: j['recurring'] == true,
        recurEvery: j['recurEvery'] as String?,
      );
}

/// A recurring template surfaced in Settings for one-tap logging.
class Recurring {
  final int id;
  final String type;
  final String category;
  final String title;
  final int amount;
  final String freq; // 'day' | 'week' | 'month' | 'year'
  final String anchor; // YYYY-MM-DD of the most recent posted occurrence
  const Recurring({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.amount,
    this.freq = 'month',
    this.anchor = '',
  });

  Recurring copyWith({String? anchor}) => Recurring(
        id: id,
        type: type,
        category: category,
        title: title,
        amount: amount,
        freq: freq,
        anchor: anchor ?? this.anchor,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'category': category,
        'title': title,
        'amount': amount,
        'freq': freq,
        'anchor': anchor,
      };

  factory Recurring.fromJson(Map<String, dynamic> j) => Recurring(
        id: (j['id'] as num).toInt(),
        type: j['type'] as String,
        category: j['category'] as String,
        title: (j['title'] ?? '') as String,
        amount: (j['amount'] as num).round(),
        freq: (j['freq'] as String?) ?? 'month',
        anchor: (j['anchor'] as String?) ?? '',
      );
}

/// Aggregated category spending slice for one month (Insights donut).
class CatSlice {
  final String key;
  final String label;
  final Color color;
  final int amount;
  final double pct; // 0..1 fraction of total monthly spending
  const CatSlice({
    required this.key,
    required this.label,
    required this.color,
    required this.amount,
    required this.pct,
  });
}

/// Income vs spent totals for one calendar month (Insights trend chart).
class MonthTotals {
  final String monthKey; // 'YYYY-MM'
  final String label;   // 3-letter abbreviation, e.g. 'Jun'
  final int income;
  final int spent;
  const MonthTotals({
    required this.monthKey,
    required this.label,
    required this.income,
    required this.spent,
  });
}

/// Derived summary stats for one calendar month (Insights summary card).
class InsightStats {
  final double savingsRate; // fraction 0..1 (negative if overspent)
  final int avgPerDay;      // average daily spend (integer amount in local currency)
  final int biggestExpense; // largest single expense amount that month
  final int prevMonthSpent; // total spent in the immediately preceding month
  final double deltaPct;    // (spent - prevSpent) / prevSpent; positive = more than last month
  const InsightStats({
    required this.savingsRate,
    required this.avgPerDay,
    required this.biggestExpense,
    required this.prevMonthSpent,
    required this.deltaPct,
  });
}

int _colorFrom(dynamic v) {
  if (v is int) return v;
  if (v is String) {
    var s = v.replaceAll('#', '').trim();
    if (s.length == 6) s = 'FF$s';
    return int.tryParse(s, radix: 16) ?? 0xFF8A8A82;
  }
  return 0xFF8A8A82;
}
