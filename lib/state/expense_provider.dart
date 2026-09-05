import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/data/models/expense.dart';
import 'package:wangku/data/repositories/expense_repository.dart';

final expenseRepositoryProvider = FutureProvider<ExpenseRepository>((ref) async {
  return ExpenseRepository.open();
});

final expensesProvider = FutureProvider<List<Expense>>((ref) async {
  final repository = await ref.watch(expenseRepositoryProvider.future);
  return repository.listAll();
});

final expensesByMonthProvider =
    FutureProvider.family<List<Expense>, DateTime>((ref, month) async {
  final repository = await ref.watch(expenseRepositoryProvider.future);
  return repository.listByMonth(month);
});

final monthlyTotalCentsProvider =
    FutureProvider.family<int, DateTime>((ref, month) async {
  final repository = await ref.watch(expenseRepositoryProvider.future);
  return repository.monthTotalCents(month);
});