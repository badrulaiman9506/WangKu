import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:wangku/data/db/app_database.dart';
import 'package:wangku/data/models/debt.dart';
import 'package:wangku/data/repositories/debt_repository.dart';

/// Objective 3: money owed in both directions, with a settle flow and
/// due-date reminders.
///
/// The direction and status CHECK constraints only hold against a real
/// database, so these run in-memory rather than against a mock.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late DebtRepository repo;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onConfigure: AppDatabase.onConfigure,
        onCreate: AppDatabase.onCreate,
      ),
    );
    repo = DebtRepository(db);
  });

  tearDown(() async => db.close());

  Debt owed({
    String name = 'Amir',
    int cents = 5000,
    DateTime? due,
    DebtDirection direction = DebtDirection.iOwe,
    String? note,
  }) {
    return Debt.create(
      direction: direction,
      personName: name,
      amountCents: cents,
      dueDate: due ?? DateTime(2026, 8, 20),
      note: note,
    );
  }

  group('create', () {
    test('inserts a debt and returns its id', () async {
      final id = await repo.insert(owed());

      expect(id, greaterThan(0));
      final saved = await repo.findById(id);
      expect(saved!.personName, 'Amir');
      expect(saved.amountCents, 5000);
      expect(saved.direction, DebtDirection.iOwe);
      expect(saved.status, DebtStatus.active);
    });

    test('stores both directions distinctly', () async {
      await repo.insert(owed(direction: DebtDirection.iOwe));
      await repo.insert(owed(direction: DebtDirection.owedToMe));

      expect((await repo.listActive(DebtDirection.iOwe)).length, 1);
      expect((await repo.listActive(DebtDirection.owedToMe)).length, 1);
    });

    test('trims a name and stores an empty note as null', () async {
      final id = await repo.insert(
        Debt.create(
          direction: DebtDirection.iOwe,
          personName: '  Siti  ',
          amountCents: 1000,
          dueDate: DateTime(2026, 8, 20),
          note: '   ',
        ),
      );

      final saved = await repo.findById(id);
      expect(saved!.personName, 'Siti');
      expect(saved.note, isNull);
    });

    test('rejects an empty name', () async {
      expect(() => repo.insert(owed(name: '   ')), throwsArgumentError);
    });

    test('rejects a zero or negative amount', () async {
      expect(() => repo.insert(owed(cents: 0)), throwsArgumentError);
      expect(() => repo.insert(owed(cents: -100)), throwsArgumentError);
    });

    test('defaults a reminder to on', () async {
      final id = await repo.insert(owed());
      expect((await repo.findById(id))!.reminderEnabled, isTrue);
    });
  });

  group('read', () {
    test('returns null for an id that does not exist', () async {
      expect(await repo.findById(404), isNull);
    });

    test('orders active debts by due date, soonest first', () async {
      await repo.insert(owed(name: 'Later', due: DateTime(2026, 9, 1)));
      await repo.insert(owed(name: 'Sooner', due: DateTime(2026, 8, 1)));
      await repo.insert(owed(name: 'Middle', due: DateTime(2026, 8, 15)));

      final active = await repo.listActive(DebtDirection.iOwe);
      expect(
        active.map((d) => d.personName).toList(),
        ['Sooner', 'Middle', 'Later'],
      );
    });

    test('active list excludes settled debts', () async {
      final id = await repo.insert(owed(name: 'Paid'));
      await repo.insert(owed(name: 'Still owing'));

      await repo.settle(id);

      final active = await repo.listActive(DebtDirection.iOwe);
      expect(active.length, 1);
      expect(active.first.personName, 'Still owing');
    });

    test('settled list contains only settled debts', () async {
      final id = await repo.insert(owed(name: 'Paid'));
      await repo.insert(owed(name: 'Still owing'));

      await repo.settle(id);

      final settled = await repo.listSettled(DebtDirection.iOwe);
      expect(settled.length, 1);
      expect(settled.first.personName, 'Paid');
    });
  });

  group('totals', () {
    test('are zero with nothing recorded', () async {
      final totals = await repo.totals();
      expect(totals.iOweCents, 0);
      expect(totals.owedToMeCents, 0);
      expect(totals.netCents, 0);
    });

    test('sum each direction separately', () async {
      await repo.insert(owed(cents: 5000, direction: DebtDirection.iOwe));
      await repo.insert(owed(cents: 3000, direction: DebtDirection.iOwe));
      await repo.insert(owed(cents: 10000, direction: DebtDirection.owedToMe));

      final totals = await repo.totals();
      expect(totals.iOweCents, 8000);
      expect(totals.owedToMeCents, 10000);
    });

    test('net is positive when more is owed to the user', () async {
      await repo.insert(owed(cents: 2000, direction: DebtDirection.iOwe));
      await repo.insert(owed(cents: 9000, direction: DebtDirection.owedToMe));

      expect((await repo.totals()).netCents, 7000);
    });

    test('exclude settled debts', () async {
      final id = await repo.insert(owed(cents: 5000));
      await repo.insert(owed(cents: 3000));

      await repo.settle(id);

      expect((await repo.totals()).iOweCents, 3000);
    });
  });

  group('settling', () {
    test('marks a debt settled and stamps the time', () async {
      final id = await repo.insert(owed());

      expect(await repo.settle(id), 1);

      final saved = await repo.findById(id);
      expect(saved!.isSettled, isTrue);
      expect(saved.settledAt, isNotNull);
    });

    test('unsettle reopens it and clears the stamp', () async {
      final id = await repo.insert(owed());
      await repo.settle(id);

      expect(await repo.unsettle(id), 1);

      final saved = await repo.findById(id);
      expect(saved!.isSettled, isFalse);
      expect(saved.settledAt, isNull);
    });

    test('settling a missing id reports zero changes', () async {
      expect(await repo.settle(404), 0);
    });
  });

  group('overdue', () {
    test('a past due date with an active status is overdue', () {
      final debt = owed(due: DateTime.now().subtract(const Duration(days: 3)));
      expect(debt.isOverdue, isTrue);
      expect(debt.daysUntilDue(), -3);
    });

    test('a future due date is not overdue', () {
      final debt = owed(due: DateTime.now().add(const Duration(days: 5)));
      expect(debt.isOverdue, isFalse);
      expect(debt.daysUntilDue(), 5);
    });

    test('today is due but not overdue', () {
      final debt = owed(due: DateTime.now());
      expect(debt.isDueToday, isTrue);
      expect(debt.isOverdue, isFalse);
    });

    test('a settled debt is never overdue, however old', () async {
      final id = await repo.insert(
        owed(due: DateTime.now().subtract(const Duration(days: 90))),
      );
      await repo.settle(id);

      final saved = await repo.findById(id);
      expect(saved!.isOverdue, isFalse);
      expect(await repo.listOverdue(), isEmpty);
    });

    test('lists overdue debts oldest first, both directions', () async {
      await repo.insert(owed(
        name: 'Recent',
        due: DateTime.now().subtract(const Duration(days: 2)),
      ));
      await repo.insert(owed(
        name: 'Ancient',
        due: DateTime.now().subtract(const Duration(days: 30)),
        direction: DebtDirection.owedToMe,
      ));
      await repo.insert(owed(
        name: 'Future',
        due: DateTime.now().add(const Duration(days: 10)),
      ));

      final overdue = await repo.listOverdue();
      expect(overdue.length, 2);
      expect(overdue.first.personName, 'Ancient');
      expect(overdue.last.personName, 'Recent');
    });
  });

  group('update and delete', () {
    test('changes amount, direction and due date', () async {
      final id = await repo.insert(owed());
      final original = await repo.findById(id);

      final changed = await repo.update(
        original!.copyWith(
          amountCents: 7500,
          direction: DebtDirection.owedToMe,
          dueDate: DateTime(2026, 12, 1),
        ),
      );

      expect(changed, 1);
      final saved = await repo.findById(id);
      expect(saved!.amountCents, 7500);
      expect(saved.direction, DebtDirection.owedToMe);
      expect(saved.dueDate, DateTime(2026, 12, 1));
    });

    test('preserves created_at and moves updated_at forward', () async {
      final createdAt = DateTime(2026, 8, 1, 9);
      final id = await repo.insert(Debt.create(
        direction: DebtDirection.iOwe,
        personName: 'Amir',
        amountCents: 1000,
        dueDate: DateTime(2026, 8, 20),
        now: createdAt,
      ));

      final original = await repo.findById(id);
      await repo.update(original!.copyWith(amountCents: 1100));
      final saved = await repo.findById(id);

      expect(saved!.createdAt, createdAt);
      expect(saved.updatedAt.isAfter(createdAt), isTrue);
    });

    test('clearNote removes an existing note', () async {
      final id = await repo.insert(owed(note: 'Lunch money'));
      final debt = await repo.findById(id);

      await repo.update(debt!.copyWith(clearNote: true));

      expect((await repo.findById(id))!.note, isNull);
    });

    test('refuses a debt with no id', () async {
      expect(() => repo.update(owed()), throwsArgumentError);
    });

    test('delete removes the row', () async {
      final id = await repo.insert(owed());

      expect(await repo.delete(id), 1);
      expect(await repo.findById(id), isNull);
      expect(await repo.count(), 0);
    });

    test('deleting a missing id reports zero changes', () async {
      expect(await repo.delete(404), 0);
    });
  });
}