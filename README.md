# Wang Ku — Increment 1 foundation

Data layer, theme, and CRUD unit tests for the Student Expense Tracker.
No feature screens yet; those come next.

## Getting these files into a project

```bash
flutter create --org my.wangku --platforms android wangku
cd wangku
```

Then copy `lib/`, `test/`, `docs/`, and `pubspec.yaml` from this folder
over the generated ones, and run:

```bash
flutter pub get
flutter test          # 22 tests, all should pass
flutter run           # opens the smoke screen on your device
```

The smoke screen in `main.dart` is temporary. It confirms three things on
a real device before any UI exists: the database file is created, the nine
categories are seeded, and an insert followed by a read comes back intact.
It gets replaced by the Home screen in the next step.

## What is here

```
docs/schema.sql                     Full DDL, commented, for the report's ERD section
lib/core/theme/app_colors.dart      Every hex value in the app
lib/core/theme/app_typography.dart  Fraunces + Inter, four sizes
lib/core/theme/app_theme.dart       Material 3 ThemeData and the spacing scale
lib/core/utils/money.dart           Cents handling, RM formatting, the 90% calculation
lib/data/db/app_database.dart       Connection owner and the v1 migration
lib/data/models/                    Category, Expense, CategoryTotal
lib/data/repositories/              Expense CRUD, category lookup
test/expense_repository_test.dart   Increment 1 test deliverable
```

## Two decisions worth defending in the report

**Money is stored as integer cents, never as REAL.** SQLite REAL is a
64-bit float, so 0.1 + 0.2 is not 0.3. Over a month of small food entries
the budget total would drift by a few sen and the 90% warning would fire
at the wrong point. Cents are exact. `Money.parse` and `Money.format` are
the only two places a decimal exists.

**All five tables are created in migration version 1**, including the
Increment 2 tables. Adding tables later would mean writing and testing an
`onUpgrade` path during the busiest week of the project. Creating them
upfront costs nothing, since an unused table holds no rows.

## Next

Increment 1 screens, in this order: Home, add-expense sheet, expense list,
edit and delete. The repository already exposes every query those screens
need.
