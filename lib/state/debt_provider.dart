import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/data/models/debt.dart';
import 'package:wangku/data/repositories/debt_repository.dart';

final debtRepositoryProvider = FutureProvider<DebtRepository>((ref) async {
  return DebtRepository.open();
});

/// Outstanding debts in one direction, soonest due first.
final activeDebtsProvider =
    FutureProvider.family<List<Debt>, DebtDirection>((ref, direction) async {
  final repository = await ref.watch(debtRepositoryProvider.future);
  return repository.listActive(direction);
});

/// Settled debts in one direction, most recently settled first.
final settledDebtsProvider =
    FutureProvider.family<List<Debt>, DebtDirection>((ref, direction) async {
  final repository = await ref.watch(debtRepositoryProvider.future);
  return repository.listSettled(direction);
});

/// Outstanding totals in both directions, for the screen header.
final debtTotalsProvider = FutureProvider<DebtTotals>((ref) async {
  final repository = await ref.watch(debtRepositoryProvider.future);
  return repository.totals();
});

/// Everything outstanding and past its due date, oldest first.
final overdueDebtsProvider = FutureProvider<List<Debt>>((ref) async {
  final repository = await ref.watch(debtRepositoryProvider.future);
  return repository.listOverdue();
});