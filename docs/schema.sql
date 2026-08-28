-- =====================================================================
-- Wang Ku (Student Expense Tracker) - SQLite schema, version 1
-- Target: sqflite on Android. All tables are created in one migration
-- so that Increment 2 needs no schema upgrade.
--
-- Money is stored as INTEGER cents, never REAL. SQLite REAL is a
-- 64-bit float, so 0.1 + 0.2 does not equal 0.3, and budget totals
-- would drift over a month of entries. Cents are exact.
--
-- Dates are stored as ISO 8601 TEXT ('2026-08-27T12:30:00.000').
-- SQLite has no date type, and ISO 8601 sorts correctly as text,
-- so range queries work without conversion.
-- =====================================================================

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------
-- categories: the fixed list from Objective 1, seeded on first run.
-- Kept as a table (not a Dart enum only) so budgets can reference a
-- real foreign key and a custom category can be added later.
-- Icon and colour are NOT stored here; they are presentation, and live
-- in a Dart map keyed by slug.
-- ---------------------------------------------------------------------
CREATE TABLE categories (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  slug        TEXT    NOT NULL UNIQUE,
  name        TEXT    NOT NULL,
  sort_order  INTEGER NOT NULL,
  is_custom   INTEGER NOT NULL DEFAULT 0 CHECK (is_custom IN (0, 1))
);

-- ---------------------------------------------------------------------
-- expenses: Increment 1 core table.
-- ---------------------------------------------------------------------
CREATE TABLE expenses (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  amount_cents  INTEGER NOT NULL CHECK (amount_cents > 0),
  category_id   INTEGER NOT NULL,
  spent_at      TEXT    NOT NULL,
  note          TEXT,
  created_at    TEXT    NOT NULL,
  updated_at    TEXT    NOT NULL,
  FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE RESTRICT
);

CREATE INDEX idx_expenses_spent_at    ON expenses (spent_at);
CREATE INDEX idx_expenses_category_id ON expenses (category_id);

-- ---------------------------------------------------------------------
-- budgets: Objective 2. One limit per category per month.
-- period is 'YYYY-MM' so a limit set in August does not silently
-- carry into September unless the user copies it forward.
-- ---------------------------------------------------------------------
CREATE TABLE budgets (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id  INTEGER NOT NULL,
  period       TEXT    NOT NULL,
  limit_cents  INTEGER NOT NULL CHECK (limit_cents > 0),
  created_at   TEXT    NOT NULL,
  updated_at   TEXT    NOT NULL,
  FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
  UNIQUE (category_id, period)
);

-- ---------------------------------------------------------------------
-- debts: Objective 4.
-- notification_id is the integer handed to flutter_local_notifications
-- when the reminder is scheduled, so the same reminder can be cancelled
-- if the debt is settled early or the due date changes.
-- ---------------------------------------------------------------------
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
);

CREATE INDEX idx_debts_due_date ON debts (due_date);
CREATE INDEX idx_debts_status   ON debts (status);

-- ---------------------------------------------------------------------
-- savings_goals: Objective 5. Static calculation only, as scoped in
-- Section 4.1 - no saved_cents column, because live progress tracking
-- is explicitly out of scope for this FYP.
-- ---------------------------------------------------------------------
CREATE TABLE savings_goals (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  title         TEXT    NOT NULL,
  target_cents  INTEGER NOT NULL CHECK (target_cents > 0),
  target_date   TEXT    NOT NULL,
  created_at    TEXT    NOT NULL,
  updated_at    TEXT    NOT NULL
);

-- ---------------------------------------------------------------------
-- Seed data: the nine categories from Objective 1.
-- ---------------------------------------------------------------------
INSERT INTO categories (slug, name, sort_order, is_custom) VALUES
  ('rent',          'Rent',          1, 0),
  ('wifi',          'Wifi',          2, 0),
  ('phone',         'Phone',         3, 0),
  ('subscriptions', 'Subscriptions', 4, 0),
  ('transport',     'Transport',     5, 0),
  ('food',          'Food',          6, 0),
  ('books',         'Books',         7, 0),
  ('fines',         'Fines',         8, 0),
  ('other',         'Other',         9, 0);
