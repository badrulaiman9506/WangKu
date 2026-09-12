import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/core/theme/app_colors.dart';
import 'package:wangku/data/models/savings_goal.dart';
import 'package:wangku/features/goals/goal_sheet.dart';
import 'package:wangku/state/index.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(savingsGoalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showGoalSheet(context),
        child: const Icon(Icons.add),
      ),
      body: goals.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 64,
                    color: AppColors.muted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No goals yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to set something to save for',
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
            itemCount: list.length,
            itemBuilder: (context, index) => _GoalCard(goal: list[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});

  final SavingsGoal goal;

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _timingLabel() {
    final days = goal.daysRemaining();
    if (days < 0) return 'Date passed';
    if (days == 0) return 'Due today';
    if (days == 1) return '1 day left';
    if (days < 30) return '$days days left';
    final months = (days / 30).floor();
    return months == 1 ? 'About 1 month left' : 'About $months months left';
  }

  @override
  Widget build(BuildContext context) {
    final target = 'RM ${(goal.targetCents / 100).toStringAsFixed(2)}';
    final weekly =
        'RM ${(goal.weeklyAmountCents() / 100).toStringAsFixed(2)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => showGoalSheet(context, goal: goal),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    target,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: goal.isPast ? AppColors.rose : AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_formatDate(goal.targetDate)}  ·  ${_timingLabel()}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              goal.isPast ? AppColors.rose : AppColors.muted,
                        ),
                  ),
                ],
              ),
              if (!goal.isPast) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Set aside $weekly a week to get there',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.coral,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}