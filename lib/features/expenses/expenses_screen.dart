import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/core/theme/app_theme.dart';
import 'package:wangku/core/theme/app_colors.dart';
import 'package:wangku/state/index.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        centerTitle: true,
        elevation: 0,
      ),
      body: expenses.when(
        data: (expenseList) {
          if (expenseList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No expenses yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: expenseList.length,
            itemBuilder: (context, index) {
              final expense = expenseList[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                    leading: CircleAvatar(
                    backgroundColor: AppColors.coral.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.shopping_bag,
                      color: AppColors.coral,
                    ),
                  ),
                  title: Text(expense.note ?? 'Expense'),
                  subtitle: Text(
                    '${expense.spentAt.day}/${expense.spentAt.month}/${expense.spentAt.year}',
                  ),
                  trailing: Text(
                    'RM ${(expense.amountCents / 100).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}