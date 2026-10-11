# WangKu: Student Expense Tracker

WangKu is an Android mobile application that helps university students keep track of their daily spending. It was developed as a Final Year Project (CC101) for the Diploma in Computer Science at Universiti Poly-Tech Malaysia (UPTM), under the supervision of Ts. Muhd Faizal bin Ahmad.

The name comes from the Malay words "wang" (money) and "ku" (my), so WangKu simply means "my money". The app runs fully offline. All data is stored on the phone itself, so no account, login or internet connection is needed.

## Features

WangKu covers four main areas, matching the objectives of the project.

1. **Expense tracking.** Students record each expense with an amount, a category, a date and an optional note. Nine categories are provided: Rent, Wifi, Phone, Subscriptions, Transport, Food, Books, Fines and Other. Expenses can be edited or deleted at any time.
2. **Monthly budgets.** A spending limit can be set for each category. The app shows how much of each limit has been used and gives a warning once spending reaches 90% of the limit, before the student overspends.
3. **Savings goals.** Students create a goal with a target amount and a target date. The app shows the days remaining and how much needs to be set aside each week to reach the goal on time.
4. **Debt tracking.** Informal debts between friends are recorded in both directions (money the student owes and money owed to the student). Each debt can have a due date with a local reminder notification, and is marked as settled once it is paid.

The Home screen gives a summary of the month, including a donut chart that breaks spending down by category.

## Tech stack

| Part | Technology |
| --- | --- |
| Framework | Flutter (Dart), Android target |
| Local database | SQLite through `sqflite` |
| State management | Riverpod (`flutter_riverpod`) |
| Charts | `fl_chart` |
| Reminders | `flutter_local_notifications` with `timezone` |
| Formatting | `intl` for RM amounts and dates |
| Fonts | Fraunces and Inter through `google_fonts` |
| Testing | `flutter_test` with `sqflite_common_ffi` |

The project followed the Incremental Model. Increment 1 delivered the database, theme and expense features. Increment 2 added budgets, savings goals, debts, reminders and the category chart.

## Project structure

```
lib/
  core/            Theme (colours, typography), money helpers, notification service
  data/            SQLite database, data models and repositories
  state/           Riverpod providers that connect the data layer to the screens
  features/        Screens: home, expenses, budgets, goals, debts and the bottom navigation shell
  main.dart        App entry point
test/              Unit tests for the expense, budget, savings goal and debt repositories
docs/schema.sql    Full database schema with comments
assets/icon/       App launcher icon
```

## Design decisions

Money is stored as whole cents in INTEGER columns rather than as REAL values. SQLite REAL is a floating point type, so small rounding errors would build up over a month of entries and could make the 90% budget warning appear at the wrong point. Using cents keeps every total exact.

All five tables (categories, expenses, budgets, debts and savings_goals) are created in the first database version, including the tables used in Increment 2. This meant the second increment did not need a database upgrade step.

## How to run

You will need the Flutter SDK (Dart 3.5 or later), Android Studio or the Android SDK, and an Android phone or emulator.

```bash
git clone https://github.com/badrulaiman9506/WangKu.git
cd WangKu
flutter pub get
flutter run
```

To run the unit tests:

```bash
flutter test
```

To build an installable APK:

```bash
flutter build apk --release
```

The APK is created at `build/app/outputs/flutter-apk/app-release.apk`.

## Author

Badrul, Diploma in Computer Science, Universiti Poly-Tech Malaysia (UPTM), 2026.
