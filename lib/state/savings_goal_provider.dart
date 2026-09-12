import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/data/models/savings_goal.dart';
import 'package:wangku/data/repositories/savings_goal_repository.dart';

final savingsGoalRepositoryProvider =
    FutureProvider<SavingsGoalRepository>((ref) async {
  return SavingsGoalRepository.open();
});

/// Sort order for the goals list. Held here rather than in the screen so
/// it survives navigation.
class SavingsGoalSortOrder extends Notifier<SavingsGoalSort> {
  @override
  SavingsGoalSort build() => SavingsGoalSort.soonestFirst;

  void set(SavingsGoalSort sort) => state = sort;
}

final savingsGoalSortProvider =
    NotifierProvider<SavingsGoalSortOrder, SavingsGoalSort>(
        SavingsGoalSortOrder.new);

final savingsGoalsProvider = FutureProvider<List<SavingsGoal>>((ref) async {
  final repository = await ref.watch(savingsGoalRepositoryProvider.future);
  final sort = ref.watch(savingsGoalSortProvider);
  return repository.listAll(sort: sort);
});

/// Goals whose target date has not passed, soonest first.
final upcomingGoalsProvider = FutureProvider<List<SavingsGoal>>((ref) async {
  final repository = await ref.watch(savingsGoalRepositoryProvider.future);
  return repository.listUpcoming();
});