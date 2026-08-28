import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Single owner of the SQLite connection.
///
/// Everything that touches the database goes through [instance]. Opening
/// the same file twice from different places is the usual source of
/// "database is locked" on Android, so there is exactly one entry point.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String fileName = 'wangku.db';
  static const int schemaVersion = 1;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final directory = await getDatabasesPath();
    final path = p.join(directory, fileName);

    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: onConfigure,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
  }

  /// Closes the connection. Used by tests and by nothing else.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // -------------------------------------------------------------------
  // Migration callbacks. Kept static and public so the unit tests can
  // build an identical in-memory database without duplicating the DDL.
  // -------------------------------------------------------------------

  static Future<void> onConfigure(Database db) async {
    // sqflite leaves foreign keys off by default. Without this the
    // FOREIGN KEY clauses below are decorative.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE categories (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        slug        TEXT    NOT NULL UNIQUE,
        name        TEXT    NOT NULL,
        sort_order  INTEGER NOT NULL,
        is_custom   INTEGER NOT NULL DEFAULT 0 CHECK (is_custom IN (0, 1))
      )
    ''');

    batch.execute('''
      CREATE TABLE expenses (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        amount_cents  INTEGER NOT NULL CHECK (amount_cents > 0),
        category_id   INTEGER NOT NULL,
        spent_at      TEXT    NOT NULL,
        note          TEXT,
        created_at    TEXT    NOT NULL,
        updated_at    TEXT    NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE RESTRICT
      )
    ''');
    batch.execute('CREATE INDEX idx_expenses_spent_at ON expenses (spent_at)');
    batch.execute(
      'CREATE INDEX idx_expenses_category_id ON expenses (category_id)',
    );

    batch.execute('''
      CREATE TABLE budgets (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id  INTEGER NOT NULL,
        period       TEXT    NOT NULL,
        limit_cents  INTEGER NOT NULL CHECK (limit_cents > 0),
        created_at   TEXT    NOT NULL,
        updated_at   TEXT    NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
        UNIQUE (category_id, period)
      )
    ''');

    batch.execute('''
      CREATE TABLE debts (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        direction         TEXT    NOT NULL CHECK (direction IN ('i_owe', 'owed_to_me')),
        person_name       TEXT    NOT NULL,
        amount_cents      INTEGER NOT NULL CHECK (amount_cents > 0),
        due_date          TEXT    NOT NULL,
        note              TEXT,
        status            TEXT    NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'settled')),
        settled_at        TEXT,
        reminder_enabled  INTEGER NOT NULL DEFAULT 1 CHECK (reminder_enabled IN (0, 1)),
        notification_id   INTEGER,
        created_at        TEXT    NOT NULL,
        updated_at        TEXT    NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_debts_due_date ON debts (due_date)');
    batch.execute('CREATE INDEX idx_debts_status ON debts (status)');

    batch.execute('''
      CREATE TABLE savings_goals (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        title         TEXT    NOT NULL,
        target_cents  INTEGER NOT NULL CHECK (target_cents > 0),
        target_date   TEXT    NOT NULL,
        created_at    TEXT    NOT NULL,
        updated_at    TEXT    NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
    await seedCategories(db);
  }

  static Future<void> onUpgrade(Database db, int from, int to) async {
    // Version 1 is the first release, so there is nothing to migrate yet.
    // Increment 2 tables are already created above on purpose. When a
    // version 2 arrives, add a `if (from < 2) { ... }` block here.
  }

  /// The nine categories from Objective 1, inserted once on first run.
  static Future<void> seedCategories(Database db) async {
    const seeds = <List<Object>>[
      ['rent', 'Rent', 1],
      ['wifi', 'Wifi', 2],
      ['phone', 'Phone', 3],
      ['subscriptions', 'Subscriptions', 4],
      ['transport', 'Transport', 5],
      ['food', 'Food', 6],
      ['books', 'Books', 7],
      ['fines', 'Fines', 8],
      ['other', 'Other', 9],
    ];

    final batch = db.batch();
    for (final seed in seeds) {
      batch.insert(
        'categories',
        {
          'slug': seed[0],
          'name': seed[1],
          'sort_order': seed[2],
          'is_custom': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }
}
