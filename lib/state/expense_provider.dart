import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/data/models/expense.dart';
import 'package:wangku/data/repositories/expense_repository.dart';
import 'package:wangku/state/app_state_provider.dart';

final expenseRepositoryProvider = FutureProvider<ExpenseRepository>((ref) async {
  return ExpenseRepository.open();
});

/// Watches the sort provider, so changing the sort re-runs the query
/// rather than sorting in the widget.
final expensesProvider = FutureProvider<List<Expense>>((ref) async {
  final repository = await ref.watch(expenseRepositoryProvider.future);
  final sort = ref.watch(expenseSortProvider);
  return repository.listAll(sort: sort);
});

final expensesByMonthProvider =
    FutureProvider.family<List<Expense>, DateTime>((ref, month) async {
  final repository = await ref.watch(expenseRepositoryProvider.future);
  final sort = ref.watch(expenseSortProvider);
  return repository.listByMonth(month, sort: sort);
});

final monthlyTotalCentsProvider =
    FutureProvider.family<int, DateTime>((ref, month) async {
  final repository = await ref.watch(expenseRepositoryProvider.future);
  return repository.monthTotalCents(month);
});

/// Per-category totals for the summary chart, largest slice first.
/// Categories with no spending in the month are left out.
final categoryTotalsProvider =
    FutureProvider.family<List<CategoryTotal>, DateTime>((ref, month) async {
  final repository = await ref.watch(expenseRepositoryProvider.future);
  return repository.totalsByCategory(month);
});