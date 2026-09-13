import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:wangku/data/db/app_database.dart';
import 'package:wangku/data/models/savings_goal.dart';
import 'package:wangku/data/repositories/savings_goal_repository.dart';

/// Objective 4: savings goals with a target amount and a target date.
///
/// The table holds no running balance, so progress is expressed as time
/// remaining and the weekly amount needed to arrive on time. Those two
/// calculations are what most of these tests cover.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late SavingsGoalRepository repo;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onConfigure: AppDatabase.onConfigure,
        onCreate: AppDatabase.onCreate,
      ),
    );
    repo = SavingsGoalRepository(db);
  });

  tearDown(() async => db.close());

  SavingsGoal goal({
    String title = 'New laptop',
    int cents = 300000,
    DateTime? date,
  }) {
    return SavingsGoal.create(
      title: title,
      targetCents: cents,
      targetDate: date ?? DateTime(2026, 12, 1),
    );
  }

  group('create', () {
    test('inserts a goal and returns its id', () async {
      final id = await repo.insert(goal());

      expect(id, greaterThan(0));
      final saved = await repo.findById(id);
      expect(saved!.title, 'New laptop');
      expect(saved.targetCents, 300000);
    });

    test('trims the title', () async {
      final id = await repo.insert(goal(title: '  Umrah fund  '));
      expect((await repo.findById(id))!.title, 'Umrah fund');
    });

    test('rejects an empty title', () async {
      expect(() => repo.insert(goal(title: '   ')), throwsArgumentError);
    });

    test('rejects a zero or negative target', () async {
      expect(() => repo.insert(goal(cents: 0)), throwsArgumentError);
      expect(() => repo.insert(goal(cents: -500)), throwsArgumentError);
    });
  });

  group('read', () {
    test('returns null for an id that does not exist', () async {
      expect(await repo.findById(404), isNull);
    });

    test('orders by target date, soonest first', () async {
      await repo.insert(goal(title: 'Later', date: DateTime(2027, 6, 1)));
      await repo.insert(goal(title: 'Sooner', date: DateTime(2026, 10, 1)));
      await repo.insert(goal(title: 'Middle', date: DateTime(2026, 12, 1)));

      final all = await repo.listAll();
      expect(
        all.map((g) => g.title).toList(),
        ['Sooner', 'Middle', 'Later'],
      );
    });

    test('sorting by largest puts the biggest target first', () async {
      await repo.insert(goal(title: 'Small', cents: 50000));
      await repo.insert(goal(title: 'Big', cents: 500000));

      final all = await repo.listAll(sort: SavingsGoalSort.largestFirst);
      expect(all.first.title, 'Big');
    });

    test('upcoming excludes goals whose date has passed', () async {
      await repo.insert(goal(
        title: 'Passed',
        date: DateTime.now().subtract(const Duration(days: 10)),
      ));
      await repo.insert(goal(
        title: 'Ahead',
        date: DateTime.now().add(const Duration(days: 10)),
      ));

      final upcoming = await repo.listUpcoming();
      expect(upcoming.length, 1);
      expect(upcoming.first.title, 'Ahead');
    });
  });

  group('days remaining', () {
    test('counts whole days to the target', () {
      final g = goal(date: DateTime(2026, 8, 20));
      expect(g.daysRemaining(from: DateTime(2026, 8, 1)), 19);
    });

    test('ignores the time of day on either side', () {
      final g = goal(date: DateTime(2026, 8, 20, 23, 59));
      expect(g.daysRemaining(from: DateTime(2026, 8, 19, 0, 1)), 1);
    });

    test('is zero on the target date itself', () {
      final g = goal(date: DateTime(2026, 8, 20));
      expect(g.daysRemaining(from: DateTime(2026, 8, 20, 15)), 0);
    });

    test('goes negative once the date has passed', () {
      final g = goal(date: DateTime(2026, 8, 20));
      expect(g.daysRemaining(from: DateTime(2026, 8, 25)), -5);
    });
  });

  group('weekly amount', () {
    test('divides the target across the weeks available', () {
      // 70 days is exactly 10 weeks.
      final g = goal(cents: 100000, date: DateTime(2026, 8, 71));
      final weekly = g.weeklyAmountCents(from: DateTime(2026, 8, 1));
      expect(weekly, 10000);
    });

    test('returns the full target inside the final week', () {
      final g = goal(cents: 50000, date: DateTime(2026, 8, 6));
      expect(g.weeklyAmountCents(from: DateTime(2026, 8, 1)), 50000);
    });

    test('returns the full target on the boundary at seven days', () {
      final g = goal(cents: 50000, date: DateTime(2026, 8, 8));
      expect(g.weeklyAmountCents(from: DateTime(2026, 8, 1)), 50000);
    });

    test('returns the full target once the date has passed', () {
      final g = goal(cents: 50000, date: DateTime(2026, 8, 1));
      expect(g.weeklyAmountCents(from: DateTime(2026, 8, 10)), 50000);
    });

    test('rounds to the nearest sen', () {
      // 300000 over 3 weeks is exactly 100000; 21 days.
      final g = goal(cents: 300000, date: DateTime(2026, 8, 22));
      expect(g.weeklyAmountCents(from: DateTime(2026, 8, 1)), 100000);
    });
  });

  group('update and delete', () {
    test('changes the title, target and date', () async {
      final id = await repo.insert(goal());
      final original = await repo.findById(id);

      final changed = await repo.update(
        original!.copyWith(
          title: 'Better laptop',
          targetCents: 450000,
          targetDate: DateTime(2027, 3, 1),
        ),
      );

      expect(changed, 1);
      final saved = await repo.findById(id);
      expect(saved!.title, 'Better laptop');
      expect(saved.targetCents, 450000);
      expect(saved.targetDate, DateTime(2027, 3, 1));
    });

    test('preserves created_at and moves updated_at forward', () async {
      final createdAt = DateTime(2026, 8, 1, 9);
      final id = await repo.insert(SavingsGoal.create(
        title: 'Laptop',
        targetCents: 100000,
        targetDate: DateTime(2026, 12, 1),
        now: createdAt,
      ));

      final original = await repo.findById(id);
      await repo.update(original!.copyWith(targetCents: 110000));
      final saved = await repo.findById(id);

      expect(saved!.createdAt, createdAt);
      expect(saved.updatedAt.isAfter(createdAt), isTrue);
    });

    test('refuses an update with an empty title', () async {
      final id = await repo.insert(goal());
      final original = await repo.findById(id);

      expect(
        () => repo.update(original!.copyWith(title: '  ')),
        throwsArgumentError,
      );
    });

    test('refuses a goal with no id', () async {
      expect(() => repo.update(goal()), throwsArgumentError);
    });

    test('delete removes the row', () async {
      final id = await repo.insert(goal());

      expect(await repo.delete(id), 1);
      expect(await repo.findById(id), isNull);
      expect(await repo.count(), 0);
    });

    test('deleting a missing id reports zero changes', () async {
      expect(await repo.delete(404), 0);
    });
  });
}