import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/budget.dart';

/// Everything the app does to the `budgets` table.
///
/// A budget is unique per category per period, enforced by a UNIQUE
/// constraint in the schema, so [setLimit] upserts rather than making the
/// caller decide between insert and update.
class BudgetRepository {
  BudgetRepository(this._db);

  final Database _db;

  static Future<BudgetRepository> open() async =>
      BudgetRepository(await AppDatabase.instance.database);

  static const String _table = 'budgets';

  // -------------------------------------------------------------------
  // Read
  // -------------------------------------------------------------------

  /// All budgets set for the month containing [month].
  Future<List<Budget>> listByMonth(DateTime month) async {
    final rows = await _db.query(
      _table,
      where: 'period = ?',
      whereArgs: [Budget.periodFor(month)],
    );
    return rows.map(Budget.fromMap).toList();
  }

  /// The limit for one category in one month, or null if none is set.
  Future<Budget?> findFor({
    required int categoryId,
    required DateTime month,
  }) async {
    final rows = await _db.query(
      _table,
      where: 'category_id = ? AND period = ?',
      whereArgs: [categoryId, Budget.periodFor(month)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Budget.fromMap(rows.first);
  }

  /// Every category paired with its limit and what has been spent against
  /// it this month. Categories with no budget are included with a null
  /// limit, so the budget screen can list all nine in one pass.
  ///
  /// The LEFT JOIN on budgets keeps categories with no limit; the second
  /// LEFT JOIN on expenses is filtered in the ON clause rather than the
  /// WHERE, so a category with no spending still returns a row.
  Future<List<BudgetStatus>> statusesForMonth(DateTime month) async {
    final period = Budget.periodFor(month);
    final range = _monthRange(month);

    final rows = await _db.rawQuery(
      '''
      SELECT c.id   AS category_id,
             c.name AS category_name,
             b.limit_cents AS limit_cents,
             COALESCE(SUM(e.amount_cents), 0) AS spent_cents
      FROM categories c
      LEFT JOIN budgets b
        ON b.category_id = c.id AND b.period = ?
      LEFT JOIN expenses e
        ON e.category_id = c.id
       AND e.spent_at >= ? AND e.spent_at < ?
      GROUP BY c.id, c.name, b.limit_cents
      ORDER BY c.sort_order ASC
      ''',
      [period, range.start, range.end],
    );

    return rows
        .map(
          (row) => BudgetStatus(
            categoryId: row['category_id'] as int,
            categoryName: row['category_name'] as String,
            limitCents: row['limit_cents'] as int?,
            spentCents: (row['spent_cents'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  /// Only the categories at or past the 90% threshold, worst first.
  /// This is what the warning banner on the home screen reads.
  Future<List<BudgetStatus>> warningsForMonth(DateTime month) async {
    final statuses = await statusesForMonth(month);
    final warnings =
        statuses.where((status) => status.ratio >= 0.9).toList();
    warnings.sort((a, b) => b.ratio.compareTo(a.ratio));
    return warnings;
  }

  // -------------------------------------------------------------------
  // Create / Update
  // -------------------------------------------------------------------

  /// Sets or replaces the limit for a category in a month.
  ///
  /// Uses the UNIQUE (category_id, period) constraint to upsert, so the
  /// caller does not have to check whether a budget already exists.
  Future<void> setLimit({
    required int categoryId,
    required DateTime month,
    required int limitCents,
  }) async {
    if (limitCents <= 0) {
      throw ArgumentError.value(
        limitCents,
        'limitCents',
        'Limit must be greater than zero',
      );
    }

    final existing = await findFor(categoryId: categoryId, month: month);

    if (existing == null) {
      final budget = Budget.create(
        categoryId: categoryId,
        month: month,
        limitCents: limitCents,
      );
      await _db.insert(_table, budget.toMap()..remove('id'));
      return;
    }

    await _db.update(
      _table,
      {
        'limit_cents': limitCents,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [existing.id],
    );
  }

  // -------------------------------------------------------------------
  // Delete
  // -------------------------------------------------------------------

  /// Removes the limit for one category in one month. Returns the number
  /// of rows deleted, so a caller can tell whether anything was set.
  Future<int> clearLimit({
    required int categoryId,
    required DateTime month,
  }) {
    return _db.delete(
      _table,
      where: 'category_id = ? AND period = ?',
      whereArgs: [categoryId, Budget.periodFor(month)],
    );
  }

  Future<int> deleteAll() => _db.delete(_table);

  // -------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------

  /// Half-open range for the calendar month, matching the expense
  /// repository so both count the same days.
  static ({String start, String end}) _monthRange(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return (start: start.toIso8601String(), end: end.toIso8601String());
  }
}