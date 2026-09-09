import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/data/models/expense.dart';

class SelectedMonth extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void set(DateTime month) => state = month;
}

final selectedMonthProvider =
    NotifierProvider<SelectedMonth, DateTime>(SelectedMonth.new);

class SelectedExpenseCategory extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? slug) => state = slug;
}

final selectedExpenseCategoryProvider =
    NotifierProvider<SelectedExpenseCategory, String?>(
        SelectedExpenseCategory.new);

/// The current month, normalised to midnight on the first. Stable across
/// rebuilds, so family providers keyed on it are not recreated every frame.
final currentMonthProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// Sort order for the expense list. Held here rather than in the screen
/// so it survives tab switches.
class ExpenseSortOrder extends Notifier<ExpenseSort> {
  @override
  ExpenseSort build() => ExpenseSort.newestFirst;

  void set(ExpenseSort sort) => state = sort;
}

final expenseSortProvider =
    NotifierProvider<ExpenseSortOrder, ExpenseSort>(ExpenseSortOrder.new);