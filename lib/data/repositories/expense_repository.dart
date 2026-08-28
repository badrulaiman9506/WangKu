import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/expense.dart';

/// Everything the app does to the `expenses` table.
///
/// The repository takes a [Database] rather than reaching for the
/// singleton itself, so the unit tests can hand it an in-memory database
/// and exercise real SQL instead of a mock.
class ExpenseRepository {
  ExpenseRepository(this._db);

  final Database _db;

  /// Convenience factory for app code.
  static Future<ExpenseRepository> open() async =>
      ExpenseRepository(await AppDatabase.instance.database);

  static const String _table = 'expenses';

  // -------------------------------------------------------------------
  // Create
  // -------------------------------------------------------------------

  /// Inserts [expense] and returns the new row id.
  ///
  /// Throws [ArgumentError] on a non-positive amount rather than letting
  /// the CHECK constraint surface as a raw DatabaseException, so the form
  /// layer has something readable to catch.
  Future<int> insert(Expense expense) async {
    if (expense.amountCents <= 0) {
      throw ArgumentError.value(
        expense.amountCents,
        'amountCents',
        'Amount must be greater than zero',
      );
    }
    final map = expense.toMap()..remove('id');
    return _db.insert(_table, map);
  }

  // -------------------------------------------------------------------
  // Read
  // -------------------------------------------------------------------

  Future<Expense?> findById(int id) async {
    final rows = await _db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Expense.fromMap(rows.first);
  }

  /// All expenses in the calendar month containing [month].
  Future<List<Expense>> listByMonth(
    DateTime month, {
    ExpenseSort sort = ExpenseSort.newestFirst,
  }) async {
    final range = _monthRange(month);
    final rows = await _db.query(
      _table,
      where: 'spent_at >= ? AND spent_at < ?',
      whereArgs: [range.start, range.end],
      orderBy: _orderBy(sort),
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<List<Expense>> listAll({
    ExpenseSort sort = ExpenseSort.newestFirst,
  }) async {
    final rows = await _db.query(_table, orderBy: _orderBy(sort));
    return rows.map(Expense.fromMap).toList();
  }

  /// Total spent in the month containing [month]. Returns 0 for an empty
  /// month, never null, so callers do not need a null guard before
  /// dividing for a percentage.
  Future<int> monthTotalCents(DateTime month) async {
    final range = _monthRange(month);
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount_cents), 0) AS total '
      'FROM $_table WHERE spent_at >= ? AND spent_at < ?',
      [range.start, range.end],
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  /// Per-category totals for the summary donut, largest slice first.
  /// Categories with no spending in the month are left out.
  Future<List<CategoryTotal>> totalsByCategory(DateTime month) async {
    final range = _monthRange(month);
    final rows = await _db.rawQuery(
      '''
      SELECT c.id   AS category_id,
             c.slug AS slug,
             c.name AS name,
             SUM(e.amount_cents) AS total_cents,
             COUNT(e.id)         AS entry_count
      FROM expenses e
      JOIN categories c ON c.id = e.category_id
      WHERE e.spent_at >= ? AND e.spent_at < ?
      GROUP BY c.id, c.slug, c.name
      ORDER BY total_cents DESC
      ''',
      [range.start, range.end],
    );
    return rows.map(CategoryTotal.fromMap).toList();
  }

  /// Total spent in one category for one month. This is the number the
  /// 90% budget warning in Objective 2 is calculated from.
  Future<int> categoryTotalCents({
    required int categoryId,
    required DateTime month,
  }) async {
    final range = _monthRange(month);
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM $_table '
      'WHERE category_id = ? AND spent_at >= ? AND spent_at < ?',
      [categoryId, range.start, range.end],
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM $_table');
    return (rows.first['n'] as int?) ?? 0;
  }

  // -------------------------------------------------------------------
  // Update / Delete
  // -------------------------------------------------------------------

  /// Returns the number of rows changed, so a caller can tell the
  /// difference between a successful edit and an edit of a row that was
  /// already deleted on another screen.
  Future<int> update(Expense expense) async {
    final id = expense.id;
    if (id == null) {
      throw ArgumentError('Cannot update an expense that has no id');
    }
    if (expense.amountCents <= 0) {
      throw ArgumentError.value(
        expense.amountCents,
        'amountCents',
        'Amount must be greater than zero',
      );
    }
    final map = expense.toMap()
      ..remove('id')
      ..remove('created_at')
      ..['updated_at'] = DateTime.now().toIso8601String();

    return _db.update(_table, map, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) =>
      _db.delete(_table, where: 'id = ?', whereArgs: [id]);

  Future<int> deleteAll() => _db.delete(_table);

  // -------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------

  static String _orderBy(ExpenseSort sort) {
    switch (sort) {
      case ExpenseSort.newestFirst:
        return 'spent_at DESC, id DESC';
      case ExpenseSort.oldestFirst:
        return 'spent_at ASC, id ASC';
      case ExpenseSort.category:
        return 'category_id ASC, spent_at DESC';
      case ExpenseSort.amountHighFirst:
        return 'amount_cents DESC, spent_at DESC';
    }
  }

  /// Half-open range for the calendar month containing [month]:
  /// start inclusive, end exclusive. Using a range instead of
  /// `substr(spent_at, 1, 7) = '2026-08'` lets SQLite use the
  /// spent_at index instead of scanning every row.
  static ({String start, String end}) _monthRange(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return (start: start.toIso8601String(), end: end.toIso8601String());
  }
}
