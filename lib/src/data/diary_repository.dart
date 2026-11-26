import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/diary_entry.dart';
import '../models/product.dart';
import 'database.dart';

/// Reads and writes the food diary and the recently-used product cache.
class DiaryRepository {
  DiaryRepository({AppDatabase? db}) : _appDb = db ?? AppDatabase.instance;

  final AppDatabase _appDb;

  Future<Database> get _db => _appDb.database;

  /// All entries for one day, planned and eaten alike, ordered by meal then
  /// by when they were added.
  Future<List<DiaryEntry>> entriesForDay(DateTime day) async {
    final db = await _db;
    final rows = await db.query(
      'entries',
      where: 'day = ?',
      whereArgs: [DateUtilsX.toKey(day)],
      orderBy: 'created_at ASC',
    );
    return rows.map(DiaryEntry.fromDbMap).toList();
  }

  Future<int> add(DiaryEntry entry) async {
    final db = await _db;
    return db.insert('entries', entry.toDbMap());
  }

  Future<void> update(DiaryEntry entry) async {
    if (entry.id == null) return;
    final db = await _db;
    await db.update(
      'entries',
      entry.toDbMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  /// Marks a planned item as eaten, keeping it in place in the day's list.
  Future<void> setStatus(int id, EntryStatus status) async {
    final db = await _db;
    await db.update(
      'entries',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Copies every entry from [from] into [to] as planned items.
  ///
  /// Used by "reuse yesterday's plan", which is the common case for people
  /// eating on a routine.
  Future<int> copyDay(
    DateTime from,
    DateTime to, {
    EntryStatus asStatus = EntryStatus.planned,
  }) async {
    final source = await entriesForDay(from);
    if (source.isEmpty) return 0;

    final db = await _db;
    final batch = db.batch();
    for (final entry in source) {
      batch.insert(
        'entries',
        entry
            .copyWith(id: null, date: DateUtilsX.dayOf(to), status: asStatus)
            .toDbMap(),
      );
    }
    await batch.commit(noResult: true);
    return source.length;
  }

  /// Total calories eaten per day over the last [days] days, for the trend
  /// chart on the history screen. Keyed by `yyyy-MM-dd`.
  Future<Map<String, double>> kcalByDay({int days = 14}) async {
    final db = await _db;
    final since = DateUtilsX.toKey(
      DateTime.now().subtract(Duration(days: days - 1)),
    );
    final rows = await db.query(
      'entries',
      columns: ['day', 'nutrients'],
      where: 'day >= ? AND status = ?',
      whereArgs: [since, EntryStatus.eaten.name],
    );

    final totals = <String, double>{};
    for (final row in rows) {
      final day = row['day'] as String;
      final kcal =
          (jsonDecode(row['nutrients'] as String) as Map)['kcal'] as num?;
      totals[day] = (totals[day] ?? 0) + (kcal?.toDouble() ?? 0);
    }
    return totals;
  }

  // --- Recently used products -------------------------------------------

  /// Remembers a product so it can be re-logged without hitting the API.
  Future<void> rememberProduct(Product product) async {
    final ean = product.ean;
    if (ean == null || ean.isEmpty) return;

    final db = await _db;
    await db.insert('recent_products', {
      'ean': ean,
      'name': product.name,
      'brand': product.brand,
      'payload': jsonEncode(product.toStorageMap()),
      'used_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Product>> recentProducts({int limit = 20}) async {
    final db = await _db;
    final rows = await db.query(
      'recent_products',
      orderBy: 'used_at DESC',
      limit: limit,
    );
    return rows
        .map(
          (r) => Product.fromStorageMap(
            jsonDecode(r['payload'] as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  /// Cached lookup for a barcode, so a rescan works offline.
  Future<Product?> cachedProductByEan(String ean) async {
    final db = await _db;
    final rows = await db.query(
      'recent_products',
      where: 'ean = ?',
      whereArgs: [ean],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromStorageMap(
      jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>,
    );
  }
}
