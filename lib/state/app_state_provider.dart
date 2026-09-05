import 'package:flutter_riverpod/flutter_riverpod.dart';

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