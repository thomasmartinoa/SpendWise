import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show Color;

import '../models.dart';
import 'database.dart';

Txn entryRowToTxn(EntryRow r) => Txn(
      id: r.id,
      date: r.date,
      type: r.type,
      category: r.category,
      title: r.title,
      amount: r.amount,
      split: r.splitTotal != null
          ? Split(total: r.splitTotal!, count: r.splitCount ?? 1)
          : null,
      recurring: r.recurring,
      recurEvery: r.recurEvery,
    );

EntriesCompanion txnToEntryCompanion(Txn t) => EntriesCompanion.insert(
      id: Value(t.id),
      date: t.date,
      type: t.type,
      category: t.category,
      title: t.title,
      amount: t.amount,
      splitTotal: Value(t.split?.total),
      splitCount: Value(t.split?.count),
      recurring: Value(t.recurring),
      recurEvery: Value(t.recurEvery),
    );

Category categoryRowToCategory(CategoryRow r) =>
    Category(key: r.key, label: r.label, color: Color(r.color));

CategoriesCompanion categoryToCompanion(Category c) => CategoriesCompanion.insert(
      key: c.key,
      label: c.label,
      color: c.color.toARGB32(),
    );

Recurring recurringRowToRecurring(RecurringRow r) => Recurring(
      id: r.id,
      type: r.type,
      category: r.category,
      title: r.title,
      amount: r.amount,
      freq: r.freq,
      anchor: r.anchor,
    );

RecurringItemsCompanion recurringToCompanion(Recurring r) =>
    RecurringItemsCompanion.insert(
      id: Value(r.id),
      type: r.type,
      category: r.category,
      title: r.title,
      amount: r.amount,
      freq: r.freq,
      anchor: r.anchor,
    );
