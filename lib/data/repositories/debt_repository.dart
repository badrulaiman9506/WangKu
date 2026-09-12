import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/debt.dart';

/// Everything the app does to the `debts` table.
class DebtRepository {
  DebtRepository(this._db);

  final Database _db;

  static Future<DebtRepository> open() async =>
      DebtRepository(await AppDatabase.instance.database);

  static const String _table = 'debts';

  // -------------------------------------------------------------------
  // Create
  // -------------------------------------------------------------------

  /// Inserts [debt] and returns the new row id.
  Future<int> insert(Debt debt) async {
    _validate(debt);
    final map = debt.toMap()..remove('id');
    return _db.insert(_table, map);
  }

  // -------------------------------------------------------------------
  // Read
  // -------------------------------------------------------------------

  Future<Debt?> findById(int id) async {
    final rows = await _db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Debt.fromMap(rows.first);
  }

  /// Outstanding debts in one direction, soonest due first. Overdue
  /// entries therefore come first, which is where attention belongs.
  Future<List<Debt>> listActive(DebtDirection direction) async {
    final rows = await _db.query(
      _table,
      where: 'direction = ? AND status = ?',
      whereArgs: [direction.dbValue, DebtStatus.active.dbValue],
      orderBy: 'due_date ASC, id ASC',
    );
    return rows.map(Debt.fromMap).toList();
  }

  /// Settled debts in one direction, most recently settled first.
  Future<List<Debt>> listSettled(DebtDirection direction) async {
    final rows = await _db.query(
      _table,
      where: 'direction = ? AND status = ?',
      whereArgs: [direction.dbValue, DebtStatus.settled.dbValue],
      orderBy: 'settled_at DESC, id DESC',
    );
    return rows.map(Debt.fromMap).toList();
  }

  Future<List<Debt>> listAll() async {
    final rows = await _db.query(_table, orderBy: 'due_date ASC, id ASC');
    return rows.map(Debt.fromMap).toList();
  }

  /// Everything still outstanding and past its due date, oldest first.
  /// Drives any overdue warning on the home screen.
  Future<List<Debt>> listOverdue() async {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final rows = await _db.query(
      _table,
      where: 'status = ? AND due_date < ?',
      whereArgs: [
        DebtStatus.active.dbValue,
        startOfToday.toIso8601String(),
      ],
      orderBy: 'due_date ASC, id ASC',
    );
    return rows.map(Debt.fromMap).toList();
  }

  /// Outstanding totals in both directions. Settled debts are excluded,
  /// so the figures answer "what do I still owe and what am I still owed".
  Future<DebtTotals> totals() async {
    final rows = await _db.rawQuery(
      '''
      SELECT direction,
             COALESCE(SUM(amount_cents), 0) AS total_cents
      FROM $_table
      WHERE status = ?
      GROUP BY direction
      ''',
      [DebtStatus.active.dbValue],
    );

    var iOwe = 0;
    var owedToMe = 0;
    for (final row in rows) {
      final total = (row['total_cents'] as int?) ?? 0;
      if (row['direction'] == DebtDirection.iOwe.dbValue) {
        iOwe = total;
      } else {
        owedToMe = total;
      }
    }

    return DebtTotals(iOweCents: iOwe, owedToMeCents: owedToMe);
  }

  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM $_table');
    return (rows.first['n'] as int?) ?? 0;
  }

  // -------------------------------------------------------------------
  // Update / Delete
  // -------------------------------------------------------------------

  Future<int> update(Debt debt) async {
    final id = debt.id;
    if (id == null) {
      throw ArgumentError('Cannot update a debt that has no id');
    }
    _validate(debt);

    final map = debt.toMap()
      ..remove('id')
      ..remove('created_at')
      ..['updated_at'] = DateTime.now().toIso8601String();

    return _db.update(_table, map, where: 'id = ?', whereArgs: [id]);
  }

  /// Marks a debt paid. Stamps `settled_at` so the settled list can be
  /// ordered by when it happened rather than when it was created.
  Future<int> settle(int id, {DateTime? when}) {
    final timestamp = (when ?? DateTime.now()).toIso8601String();
    return _db.update(
      _table,
      {
        'status': DebtStatus.settled.dbValue,
        'settled_at': timestamp,
        'updated_at': timestamp,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Reopens a settled debt, for a mistaken tap.
  Future<int> unsettle(int id) {
    return _db.update(
      _table,
      {
        'status': DebtStatus.active.dbValue,
        'settled_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) =>
      _db.delete(_table, where: 'id = ?', whereArgs: [id]);

  Future<int> deleteAll() => _db.delete(_table);

  // -------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------

  static void _validate(Debt debt) {
    if (debt.personName.trim().isEmpty) {
      throw ArgumentError.value(
        debt.personName,
        'personName',
        'Enter who this is with',
      );
    }
    if (debt.amountCents <= 0) {
      throw ArgumentError.value(
        debt.amountCents,
        'amountCents',
        'Amount must be greater than zero',
      );
    }
  }
}