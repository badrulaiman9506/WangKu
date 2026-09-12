import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/savings_goal.dart';

/// Everything the app does to the `savings_goals` table.
class SavingsGoalRepository {
  SavingsGoalRepository(this._db);

  final Database _db;

  static Future<SavingsGoalRepository> open() async =>
      SavingsGoalRepository(await AppDatabase.instance.database);

  static const String _table = 'savings_goals';

  // -------------------------------------------------------------------
  // Create
  // -------------------------------------------------------------------

  /// Inserts [goal] and returns the new row id.
  ///
  /// Throws [ArgumentError] on an empty title or a non-positive target
  /// rather than letting the CHECK constraint surface as a raw
  /// DatabaseException, so the form layer has something readable to catch.
  Future<int> insert(SavingsGoal goal) async {
    _validate(goal);
    final map = goal.toMap()..remove('id');
    return _db.insert(_table, map);
  }

  // -------------------------------------------------------------------
  // Read
  // -------------------------------------------------------------------

  Future<SavingsGoal?> findById(int id) async {
    final rows = await _db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SavingsGoal.fromMap(rows.first);
  }

  Future<List<SavingsGoal>> listAll({
    SavingsGoalSort sort = SavingsGoalSort.soonestFirst,
  }) async {
    final rows = await _db.query(_table, orderBy: _orderBy(sort));
    return rows.map(SavingsGoal.fromMap).toList();
  }

  /// Goals whose target date has not yet passed, soonest first.
  Future<List<SavingsGoal>> listUpcoming() async {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final rows = await _db.query(
      _table,
      where: 'target_date >= ?',
      whereArgs: [startOfToday.toIso8601String()],
      orderBy: 'target_date ASC, id ASC',
    );
    return rows.map(SavingsGoal.fromMap).toList();
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
  /// already deleted elsewhere.
  Future<int> update(SavingsGoal goal) async {
    final id = goal.id;
    if (id == null) {
      throw ArgumentError('Cannot update a goal that has no id');
    }
    _validate(goal);

    final map = goal.toMap()
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

  static void _validate(SavingsGoal goal) {
    if (goal.title.trim().isEmpty) {
      throw ArgumentError.value(
        goal.title,
        'title',
        'Give the goal a name',
      );
    }
    if (goal.targetCents <= 0) {
      throw ArgumentError.value(
        goal.targetCents,
        'targetCents',
        'Target must be greater than zero',
      );
    }
  }

  static String _orderBy(SavingsGoalSort sort) {
    switch (sort) {
      case SavingsGoalSort.soonestFirst:
        return 'target_date ASC, id ASC';
      case SavingsGoalSort.largestFirst:
        return 'target_cents DESC, target_date ASC';
      case SavingsGoalSort.newestFirst:
        return 'created_at DESC, id DESC';
    }
  }
}