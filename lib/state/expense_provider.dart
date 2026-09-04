import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/data/models/expense.dart';
import 'package:wangku/data/repositories/expense_repository.dart';

final expenseRepositoryProvider = Provider((ref) {
  return ExpenseRepository();
});

final expensesProvider = FutureProvider<List<Expense>>((ref) async {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getAllExpenses();
});

final expensesByMonthProvider = FutureProvider.family<List<Expense>, DateTime>((ref, month) async {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getExpensesByMonth(month);
});

final monthlyTotalProvider = FutureProvider.family<double, DateTime>((ref, month) async {
  final repository = ref.watch(expenseRepositoryProvider);
  final expenses = await repository.getExpensesByMonth(month);
  return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
});