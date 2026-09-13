import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/core/theme/app_colors.dart';
import 'package:wangku/data/models/budget.dart';
import 'package:wangku/data/models/debt.dart';
import 'package:wangku/data/models/expense.dart';
import 'package:wangku/features/budgets/index.dart';
import 'package:wangku/features/expenses/add_expense_sheet.dart';
import 'package:wangku/features/goals/index.dart';
import 'package:wangku/state/index.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  /// Slice colours, reused in order. Nine categories, nine colours, so
  /// a category keeps the same colour as long as the seed order holds.
  static const _sliceColors = <Color>[
    Color(0xFFD97156),
    Color(0xFF2E4057),
    Color(0xFFE0A458),
    Color(0xFF6A8D73),
    Color(0xFFA65D57),
    Color(0xFF7D8CA3),
    Color(0xFFC9A227),
    Color(0xFF5B7B7A),
    Color(0xFF9C8AA5),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(currentMonthProvider);
    final monthlyTotal = ref.watch(monthlyTotalCentsProvider(month));
    final categoryTotals = ref.watch(categoryTotalsProvider(month));
    final warnings = ref.watch(budgetWarningsProvider(month));
    final overdue = ref.watch(overdueDebtsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wang Ku'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Budgets',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BudgetsScreen()),
              );
              ref.invalidate(budgetWarningsProvider);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.coral,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Month',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white60,
                          ),
                    ),
                    const SizedBox(height: 8),
                    monthlyTotal.when(
                      data: (cents) => Text(
                        'RM ${(cents / 100).toStringAsFixed(2)}',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      loading: () =>
                          const CircularProgressIndicator(color: Colors.white),
                      error: (err, stack) => Text(
                        'Error: $err',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              overdue.maybeWhen(
                data: (list) => list.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _OverdueDebtCard(debts: list),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
              warnings.maybeWhen(
                data: (list) => list.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _BudgetWarningCard(warnings: list),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => showAddExpenseSheet(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Expense'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => showGoalSheet(context),
                      icon: const Icon(Icons.trending_up),
                      label: const Text('Set Goal'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Where it went',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              categoryTotals.when(
                data: (totals) => _buildBreakdown(context, totals),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) => Text('Error: $err'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdown(BuildContext context, List<CategoryTotal> totals) {
    if (totals.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        alignment: Alignment.center,
        child: Text(
          'Nothing logged this month yet',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
        ),
      );
    }

    final grandTotal =
        totals.fold<int>(0, (sum, total) => sum + total.totalCents);

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 56,
              sections: [
                for (var i = 0; i < totals.length; i++)
                  PieChartSectionData(
                    value: totals[i].totalCents.toDouble(),
                    color: _sliceColors[i % _sliceColors.length],
                    radius: 32,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < totals.length; i++)
          _LegendRow(
            color: _sliceColors[i % _sliceColors.length],
            name: totals[i].name,
            cents: totals[i].totalCents,
            percentage: grandTotal == 0
                ? 0
                : (totals[i].totalCents / grandTotal) * 100,
          ),
      ],
    );
  }
}

/// Shown when any debt is past its due date and still outstanding.
class _OverdueDebtCard extends StatelessWidget {
  const _OverdueDebtCard({required this.debts});

  final List<Debt> debts;

  String _line(Debt debt) {
    final amount = 'RM ${(debt.amountCents / 100).toStringAsFixed(2)}';
    final days = -debt.daysUntilDue();
    final ago = days == 1 ? '1 day' : '$days days';
    return debt.direction == DebtDirection.iOwe
        ? 'You owe ${debt.personName} $amount ($ago late)'
        : '${debt.personName} owes you $amount ($ago late)';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.rose.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: AppColors.rose, size: 20),
              const SizedBox(width: 8),
              Text(
                debts.length == 1 ? 'Overdue' : '${debts.length} overdue',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.rose,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final debt in debts)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _line(debt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown above the chart when any category has reached 90% of its limit.
class _BudgetWarningCard extends StatelessWidget {
  const _BudgetWarningCard({required this.warnings});

  final List<BudgetStatus> warnings;

  @override
  Widget build(BuildContext context) {
    final anyOver = warnings.any((status) => status.isOverLimit);
    final accent = anyOver ? AppColors.rose : const Color(0xFFE0A458);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(
                anyOver ? 'Over budget' : 'Close to your limit',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: accent,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final status in warnings)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${status.categoryName}: '
                'RM ${(status.spentCents / 100).toStringAsFixed(2)} of '
                'RM ${(status.limitCents! / 100).toStringAsFixed(2)} '
                '(${(status.ratio * 100).toStringAsFixed(0)}%)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.name,
    required this.cents,
    required this.percentage,
  });

  final Color color;
  final String name;
  final int cents;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              'RM ${(cents / 100).toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}