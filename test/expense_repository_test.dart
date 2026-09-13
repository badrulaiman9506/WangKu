import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:wangku/data/db/app_database.dart';
import 'package:wangku/data/models/budget.dart';
import 'package:wangku/data/models/expense.dart';
import 'package:wangku/data/repositories/budget_repository.dart';
import 'package:wangku/data/repositories/expense_repository.dart';

/// Objective 2: monthly limits per category, with a warning once spending
/// reaches 90% of the limit.
///
/// Run against a real in-memory database so the UNIQUE constraint on
/// (category_id, period) and the LEFT JOIN in statusesForMonth are both
/// actually exercised.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late BudgetRepository repo;
  late ExpenseRepository expenses;
  late int foodId;
  late int transportId;

  final august = DateTime(2026, 8);

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onConfigure: AppDatabase.onConfigure,
        onCreate: AppDatabase.onCreate,
      ),
    );
    repo = BudgetRepository(db);
    expenses = ExpenseRepository(db);

    final categories = await db.query('categories');
    foodId = categories.firstWhere((c) => c['slug'] == 'food')['id'] as int;
    transportId =
        categories.firstWhere((c) => c['slug'] == 'transport')['id'] as int;
  });

  tearDown(() async => db.close());

  group('period formatting', () {
    test('pads the month to two digits', () {
      expect(Budget.periodFor(DateTime(2026, 8)), '2026-08');
      expect(Budget.periodFor(DateTime(2026, 12)), '2026-12');
    });

    test('ignores the day within the month', () {
      expect(Budget.periodFor(DateTime(2026, 8, 1)), '2026-08');
      expect(Budget.periodFor(DateTime(2026, 8, 31)), '2026-08');
    });
  });

  group('setting a limit', () {
    test('stores a new limit', () async {
      await repo.setLimit(
        categoryId: foodId,
        month: august,
        limitCents: 45000,
      );

      final saved = await repo.findFor(categoryId: foodId, month: august);
      expect(saved, isNotNull);
      expect(saved!.limitCents, 45000);
      expect(saved.period, '2026-08');
    });

    test('replaces rather than duplicates an existing limit', () async {
      await repo.setLimit(
        categoryId: foodId,
        month: august,
        limitCents: 45000,
      );
      await repo.setLimit(
        categoryId: foodId,
        month: august,
        limitCents: 50000,
      );

      final all = await repo.listByMonth(august);
      expect(all.length, 1);
      expect(all.first.limitCents, 50000);
    });

    test('keeps limits for different months apart', () async {
      await repo.setLimit(
        categoryId: foodId,
        month: august,
        limitCents: 45000,
      );
      await repo.setLimit(
        categoryId: foodId,
        month: DateTime(2026, 9),
        limitCents: 30000,
      );

      expect((await repo.listByMonth(august)).length, 1);
      expect(
        (await repo.findFor(categoryId: foodId, month: DateTime(2026, 9)))!
            .limitCents,
        30000,
      );
    });

    test('rejects a zero or negative limit', () async {
      expect(
        () => repo.setLimit(
          categoryId: foodId,
          month: august,
          limitCents: 0,
        ),
        throwsArgumentError,
      );
    });

    test('returns null when no limit is set', () async {
      expect(await repo.findFor(categoryId: foodId, month: august), isNull);
    });
  });

  group('statuses', () {
    test('lists every category even with no budget or spending', () async {
      final statuses = await repo.statusesForMonth(august);

      expect(statuses.length, 9);
      expect(statuses.every((s) => s.limitCents == null), isTrue);
      expect(statuses.every((s) => s.spentCents == 0), isTrue);
    });

    test('pairs a limit with what has been spent against it', () async {
      await repo.setLimit(
        categoryId: foodId,
        month: august,
        limitCents: 45000,
      );
      await expenses.insert(Expense.create(
        amountCents: 20000,
        categoryId: foodId,
        spentAt: DateTime(2026, 8, 10),
      ));

      final food = (await repo.statusesForMonth(august))
          .firstWhere((s) => s.categoryId == foodId);

      expect(food.limitCents, 45000);
      expect(food.spentCents, 20000);
      expect(food.hasLimit, isTrue);
    });

    test('counts only spending inside the month', () async {
      await repo.setLimit(
        categoryId: foodId,
        month: august,
        limitCents: 45000,
      );
      await expenses.insert(Expense.create(
        amountCents: 10000,
        categoryId: foodId,
        spentAt: DateTime(2026, 7, 31, 23, 59),
      ));
      await expenses.insert(Expense.create(
        amountCents: 20000,
        categoryId: foodId,
        spentAt: DateTime(2026, 8, 1),
      ));
      await expenses.insert(Expense.create(
        amountCents: 30000,
        categoryId: foodId,
        spentAt: DateTime(2026, 9, 1),
      ));

      final food = (await repo.statusesForMonth(august))
          .firstWhere((s) => s.categoryId == foodId);

      expect(food.spentCents, 20000);
    });

    test('shows spending for a category with no limit set', () async {
      await expenses.insert(Expense.create(
        amountCents: 5000,
        categoryId: transportId,
        spentAt: DateTime(2026, 8, 5),
      ));

      final transport = (await repo.statusesForMonth(august))
          .firstWhere((s) => s.categoryId == transportId);

      expect(transport.hasLimit, isFalse);
      expect(transport.spentCents, 5000);
      expect(transport.ratio, 0);
    });
  });

  group('the 90% threshold', () {
    Future<void> setUpFood({
      required int limitCents,
      required int spentCents,
    }) async {
      await repo.setLimit(
        categoryId: foodId,
        month: august,
        limitCents: limitCents,
      );
      if (spentCents > 0) {
        await expenses.insert(Expense.create(
          amountCents: spentCents,
          categoryId: foodId,
          spentAt: DateTime(2026, 8, 10),
        ));
      }
    }

    test('is not near the limit just below 90%', () async {
      await setUpFood(limitCents: 45000, spentCents: 40000);

      final food = (await repo.statusesForMonth(august))
          .firstWhere((s) => s.categoryId == foodId);

      expect(food.isNearLimit, isFalse);
      expect(food.isOverLimit, isFalse);
      expect(await repo.warningsForMonth(august), isEmpty);
    });

    test('is near the limit exactly at 90%', () async {
      await setUpFood(limitCents: 45000, spentCents: 40500);

      final food = (await repo.statusesForMonth(august))
          .firstWhere((s) => s.categoryId == foodId);

      expect(food.isNearLimit, isTrue);
      expect(food.isOverLimit, isFalse);
      expect((await repo.warningsForMonth(august)).length, 1);
    });

    test('is over the limit at exactly 100%', () async {
      await setUpFood(limitCents: 45000, spentCents: 45000);

      final food = (await repo.statusesForMonth(august))
          .firstWhere((s) => s.categoryId == foodId);

      expect(food.isNearLimit, isFalse);
      expect(food.isOverLimit, isTrue);
      expect(food.remainingCents, 0);
    });

    test('reports how far over the limit spending has gone', () async {
      await setUpFood(limitCents: 12000, spentCents: 12500);

      final food = (await repo.statusesForMonth(august))
          .firstWhere((s) => s.categoryId == foodId);

      expect(food.isOverLimit, isTrue);
      expect(food.remainingCents, -500);
    });

    test('orders warnings worst first', () async {
      await repo.setLimit(
        categoryId: foodId,
        month: august,
        limitCents: 10000,
      );
      await repo.setLimit(
        categoryId: transportId,
        month: august,
        limitCents: 10000,
      );
      // Food at 95%, transport at 120%.
      await expenses.insert(Expense.create(
        amountCents: 9500,
        categoryId: foodId,
        spentAt: DateTime(2026, 8, 5),
      ));
      await expenses.insert(Expense.create(
        amountCents: 12000,
        categoryId: transportId,
        spentAt: DateTime(2026, 8, 6),
      ));

      final warnings = await repo.warningsForMonth(august);

      expect(warnings.length, 2);
      expect(warnings.first.categoryId, transportId);
      expect(warnings.last.categoryId, foodId);
    });

    test('a category with no limit never warns, however much is spent',
        () async {
      await expenses.insert(Expense.create(
        amountCents: 500000,
        categoryId: transportId,
        spentAt: DateTime(2026, 8, 5),
      ));

      expect(await repo.warningsForMonth(august), isEmpty);
    });
  });

  group('clearing a limit', () {
    test('removes it and reports one row deleted', () async {
      await repo.setLimit(
        categoryId: foodId,
        month: august,
        limitCents: 45000,
      );

      expect(
        await repo.clearLimit(categoryId: foodId, month: august),
        1,
      );
      expect(await repo.findFor(categoryId: foodId, month: august), isNull);
    });

    test('clearing a limit that was never set reports zero', () async {
      expect(
        await repo.clearLimit(categoryId: foodId, month: august),
        0,
      );
    });

    test('leaves spending untouched', () async {
      await repo.setLimit(
        categoryId: foodId,
        month: august,
        limitCents: 45000,
      );
      await expenses.insert(Expense.create(
        amountCents: 20000,
        categoryId: foodId,
        spentAt: DateTime(2026, 8, 10),
      ));

      await repo.clearLimit(categoryId: foodId, month: august);

      final food = (await repo.statusesForMonth(august))
          .firstWhere((s) => s.categoryId == foodId);
      expect(food.hasLimit, isFalse);
      expect(food.spentCents, 20000);
    });
  });
}