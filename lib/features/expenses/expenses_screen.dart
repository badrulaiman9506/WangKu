import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/core/theme/app_colors.dart';
import 'package:wangku/data/models/expense.dart';
import 'package:wangku/features/expenses/add_expense_sheet.dart';
import 'package:wangku/state/index.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider);
    final categories = ref.watch(categoriesByIdProvider);
    final sort = ref.watch(expenseSortProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        centerTitle: true,
        elevation: 0,
        actions: [
          PopupMenuButton<ExpenseSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: sort,
            onSelected: (value) =>
                ref.read(expenseSortProvider.notifier).set(value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: ExpenseSort.newestFirst,
                child: Text('Newest first'),
              ),
              PopupMenuItem(
                value: ExpenseSort.oldestFirst,
                child: Text('Oldest first'),
              ),
              PopupMenuItem(
                value: ExpenseSort.amountHighFirst,
                child: Text('Highest amount'),
              ),
              PopupMenuItem(
                value: ExpenseSort.category,
                child: Text('Category'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddExpenseSheet(context),
        child: const Icon(Icons.add),
      ),
      body: expenses.when(
        data: (expenseList) {
          if (expenseList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: AppColors.muted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No expenses yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add your first one',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: expenseList.length,
            itemBuilder: (context, index) {
              final expense = expenseList[index];
              final categoryName = categories.maybeWhen(
                data: (map) => map[expense.categoryId]?.name ?? 'Uncategorised',
                orElse: () => '',
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () => showAddExpenseSheet(context, expense: expense),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.coral.withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      color: AppColors.coral,
                    ),
                  ),
                  title: Text(categoryName),
                  subtitle: Text(
                    expense.note?.isNotEmpty == true
                        ? '${expense.note}  ·  ${_formatDate(expense.spentAt)}'
                        : _formatDate(expense.spentAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

  /// Omits the year for the current year, which is the common case and
  /// keeps the subtitle on one line.
  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final sameYear = date.year == DateTime.now().year;
    return sameYear
        ? '${date.day} ${months[date.month - 1]}'
        : '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}