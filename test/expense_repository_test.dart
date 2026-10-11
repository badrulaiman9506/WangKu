import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:wangku/core/utils/money.dart';
import 'package:wangku/data/db/app_database.dart';
import 'package:wangku/data/models/expense.dart';
import 'package:wangku/data/repositories/expense_repository.dart';

/// Increment 1 deliverable: "Unit tests for expense CRUD operations, run
/// against a set of expected input/output cases."
///
/// These run against a real in-memory SQLite database rather than a mock,
/// so the CHECK constraints, the foreign key, and the date range queries
/// are all actually exercised.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ExpenseRepository repo;
  late int foodId;
  late int transportId;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onConfigure: AppDatabase.onConfigure,
        onCreate: AppDatabase.onCreate,
      ),
    );
    repo = ExpenseRepository(db);

    final categories = await db.query('categories');
    foodId = categories.firstWhere((c) => c['slug'] == 'food')['id'] as int;
    transportId =
        categories.firstWhere((c) => c['slug'] == 'transport')['id'] as int;
  });

  tearDown(() async => db.close());

  group('seed data', () {
    test('creates the nine categories from Objective 1', () async {
      final rows = await db.query('categories');
      expect(rows.length, 9);
      expect(
        rows.map((r) => r['slug']),
        containsAll(<String>[
          'rent',
          'bills',
          'transport',
          'food',
          'education',
          'personal',
          'leisure',
          'giving',
          'other',
        ]),
      );
    });
  });

  group('create', () {
    test('inserts an expense and returns its id', () async {
      final id = await repo.insert(
        Expense.create(amountCents: 1200, categoryId: foodId),
      );

      expect(id, greaterThan(0));
      final saved = await repo.findById(id);
      expect(saved, isNotNull);
      expect(saved!.amountCents, 1200);
      expect(saved.categoryId, foodId);
    });

    test('trims a note and stores an empty note as null', () async {
      final id = await repo.insert(
        Expense.create(
          amountCents: 850,
          categoryId: transportId,
          note: '  Grab to campus  ',
        ),
      );
      final blankId = await repo.insert(
        Expense.create(amountCents: 500, categoryId: foodId, note: '   '),
      );

      expect((await repo.findById(id))!.note, 'Grab to campus');
      expect((await repo.findById(blankId))!.note, isNull);
    });

    test('rejects a zero or negative amount', () async {
      expect(
        () => repo.insert(Expense.create(amountCents: 0, categoryId: foodId)),
        throwsArgumentError,
      );
      expect(
        () => repo.insert(Expense.create(amountCents: -50, categoryId: foodId)),
        throwsArgumentError,
      );
    });

    test('rejects an unknown category', () async {
      expect(
        () => repo.insert(Expense.create(amountCents: 100, categoryId: 9999)),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('read', () {
    test('returns null for an id that does not exist', () async {
      expect(await repo.findById(404), isNull);
    });

    test('lists only expenses inside the requested month', () async {
      await repo.insert(Expense.create(
        amountCents: 1000,
        categoryId: foodId,
        spentAt: DateTime(2026, 7, 31, 23, 59),
      ));
      await repo.insert(Expense.create(
        amountCents: 2000,
        categoryId: foodId,
        spentAt: DateTime(2026, 8, 1, 0, 1),
      ));
      await repo.insert(Expense.create(
        amountCents: 3000,
        categoryId: foodId,
        spentAt: DateTime(2026, 8, 31, 23, 59),
      ));
      await repo.insert(Expense.create(
        amountCents: 4000,
        categoryId: foodId,
        spentAt: DateTime(2026, 9, 1, 0, 1),
      ));

      final august = await repo.listByMonth(DateTime(2026, 8, 15));
      expect(august.length, 2);
      expect(
        august.map((e) => e.amountCents).toList(),
        [3000, 2000], // newest first
      );
    });

    test('month total is zero for a month with no entries', () async {
      expect(await repo.monthTotalCents(DateTime(2026, 8)), 0);
    });

    test('month total sums only that month', () async {
      await repo.insert(Expense.create(
        amountCents: 41800,
        categoryId: foodId,
        spentAt: DateTime(2026, 8, 10),
      ));
      await repo.insert(Expense.create(
        amountCents: 17500,
        categoryId: transportId,
        spentAt: DateTime(2026, 8, 20),
      ));
      await repo.insert(Expense.create(
        amountCents: 99900,
        categoryId: foodId,
        spentAt: DateTime(2026, 9, 2),
      ));

      expect(await repo.monthTotalCents(DateTime(2026, 8)), 59300);
    });

    test('category totals are grouped and ordered largest first', () async {
      await repo.insert(Expense.create(
        amountCents: 1000,
        categoryId: transportId,
        spentAt: DateTime(2026, 8, 5),
      ));
      await repo.insert(Expense.create(
        amountCents: 2500,
        categoryId: foodId,
        spentAt: DateTime(2026, 8, 6),
      ));
      await repo.insert(Expense.create(
        amountCents: 1500,
        categoryId: foodId,
        spentAt: DateTime(2026, 8, 7),
      ));

      final totals = await repo.totalsByCategory(DateTime(2026, 8));

      expect(totals.length, 2);
      expect(totals.first.slug, 'food');
      expect(totals.first.totalCents, 4000);
      expect(totals.first.entryCount, 2);
      expect(totals.last.slug, 'transport');
      expect(totals.last.totalCents, 1000);
    });

    test('sorting by oldest reverses the list', () async {
      await repo.insert(Expense.create(
        amountCents: 100,
        categoryId: foodId,
        spentAt: DateTime(2026, 8, 1),
      ));
      await repo.insert(Expense.create(
        amountCents: 200,
        categoryId: foodId,
        spentAt: DateTime(2026, 8, 9),
      ));

      final oldest = await repo.listAll(sort: ExpenseSort.oldestFirst);
      expect(oldest.map((e) => e.amountCents).toList(), [100, 200]);
    });
  });

  group('update', () {
    test('changes the amount and category of an existing row', () async {
      final id = await repo.insert(
        Expense.create(amountCents: 1200, categoryId: foodId),
      );
      final original = await repo.findById(id);

      final changed = await repo.update(
        original!.copyWith(amountCents: 1500, categoryId: transportId),
      );

      expect(changed, 1);
      final saved = await repo.findById(id);
      expect(saved!.amountCents, 1500);
      expect(saved.categoryId, transportId);
    });

    test('preserves created_at and moves updated_at forward', () async {
      final createdAt = DateTime(2026, 8, 1, 9);
      final id = await repo.insert(Expense.create(
        amountCents: 1000,
        categoryId: foodId,
        now: createdAt,
      ));

      final original = await repo.findById(id);
      await repo.update(original!.copyWith(amountCents: 1100));
      final saved = await repo.findById(id);

      expect(saved!.createdAt, createdAt);
      expect(saved.updatedAt.isAfter(createdAt), isTrue);
    });

    test('returns zero rows when the id no longer exists', () async {
      final id = await repo.insert(
        Expense.create(amountCents: 1000, categoryId: foodId),
      );
      final expense = await repo.findById(id);
      await repo.delete(id);

      expect(await repo.update(expense!.copyWith(amountCents: 2000)), 0);
    });

    test('refuses an expense with no id', () async {
      expect(
        () => repo.update(Expense.create(amountCents: 100, categoryId: foodId)),
        throwsArgumentError,
      );
    });

    test('clearNote removes an existing note', () async {
      final id = await repo.insert(Expense.create(
        amountCents: 1000,
        categoryId: foodId,
        note: 'Nasi ayam',
      ));
      final expense = await repo.findById(id);

      await repo.update(expense!.copyWith(clearNote: true));

      expect((await repo.findById(id))!.note, isNull);
    });
  });

  group('delete', () {
    test('removes the row and reports one change', () async {
      final id = await repo.insert(
        Expense.create(amountCents: 1000, categoryId: foodId),
      );

      expect(await repo.delete(id), 1);
      expect(await repo.findById(id), isNull);
      expect(await repo.count(), 0);
    });

    test('deleting a missing id reports zero changes', () async {
      expect(await repo.delete(404), 0);
    });
  });

  group('Money', () {
    test('formats cents as ringgit', () {
      expect(Money.format(121200), 'RM 1,212.00');
      expect(Money.format(0), 'RM 0.00');
      expect(Money.format(5), 'RM 0.05');
    });

    test('parses the formats a student will actually type', () {
      expect(Money.parse('12'), 1200);
      expect(Money.parse('12.5'), 1250);
      expect(Money.parse('12.50'), 1250);
      expect(Money.parse('RM 12.50'), 1250);
      expect(Money.parse('1,212.00'), 121200);
    });

    test('rejects input that is not a usable amount', () {
      expect(Money.parse(''), isNull);
      expect(Money.parse('abc'), isNull);
      expect(Money.parse('0'), isNull);
      expect(Money.parse('1.2.3'), isNull);
    });

    test('rounds rather than truncating the third decimal', () {
      expect(Money.parse('12.999'), 1300);
    });

    test('percentUsed crosses the 90% warning threshold correctly', () {
      // The exact boundary from Objective 2.
      expect(Money.percentUsed(spentCents: 40500, limitCents: 45000), 90);
      expect(Money.percentUsed(spentCents: 40499, limitCents: 45000), 90);
      expect(Money.percentUsed(spentCents: 41800, limitCents: 45000), 93);
      expect(Money.percentUsed(spentCents: 12500, limitCents: 12000), 104);
      expect(Money.percentUsed(spentCents: 1000, limitCents: 0), 0);
    });
  });
}