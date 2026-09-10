import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/data/models/budget.dart';
import 'package:wangku/data/repositories/budget_repository.dart';

final budgetRepositoryProvider = FutureProvider<BudgetRepository>((ref) async {
  return BudgetRepository.open();
});

/// Every category with its limit and spending for the month. This is what
/// the budget screen lists.
final budgetStatusesProvider =
    FutureProvider.family<List<BudgetStatus>, DateTime>((ref, month) async {
  final repository = await ref.watch(budgetRepositoryProvider.future);
  return repository.statusesForMonth(month);
});

/// Only the categories at or past 90%, worst first. Drives the warning
/// card on the home screen.
final budgetWarningsProvider =
    FutureProvider.family<List<BudgetStatus>, DateTime>((ref, month) async {
  final repository = await ref.watch(budgetRepositoryProvider.future);
  return repository.warningsForMonth(month);
});