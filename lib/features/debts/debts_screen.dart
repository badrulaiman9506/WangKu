import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/core/theme/app_colors.dart';
import 'package:wangku/data/models/debt.dart';
import 'package:wangku/features/debts/debt_sheet.dart';
import 'package:wangku/state/index.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Which direction a new entry defaults to, based on the visible tab.
  DebtDirection get _currentDirection => _tabController.index == 0
      ? DebtDirection.iOwe
      : DebtDirection.owedToMe;

  @override
  Widget build(BuildContext context) {
    final totals = ref.watch(debtTotalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debts'),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'I owe'),
            Tab(text: 'Owed to me'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDebtSheet(
          context,
          direction: _currentDirection,
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          totals.maybeWhen(
            data: (data) => _TotalsBar(totals: data),
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _DebtList(direction: DebtDirection.iOwe),
                _DebtList(direction: DebtDirection.owedToMe),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsBar extends StatelessWidget {
  const _TotalsBar({required this.totals});

  final DebtTotals totals;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _TotalTile(
              label: 'I owe',
              cents: totals.iOweCents,
              color: AppColors.rose,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TotalTile(
              label: 'Owed to me',
              cents: totals.owedToMeCents,
              color: AppColors.coral,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.cents,
    required this.color,
  });

  final String label;
  final int cents;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'RM ${(cents / 100).toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _DebtList extends ConsumerWidget {
  const _DebtList({required this.direction});

  final DebtDirection direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeDebtsProvider(direction));
    final settled = ref.watch(settledDebtsProvider(direction));

    return active.when(
      data: (activeList) {
        final settledList = settled.maybeWhen(
          data: (list) => list,
          orElse: () => const <Debt>[],
        );

        if (activeList.isEmpty && settledList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.handshake_outlined,
                  size: 64,
                  color: AppColors.muted,
                ),
                const SizedBox(height: 16),
                Text(
                  direction == DebtDirection.iOwe
                      ? 'You owe nothing'
                      : 'Nobody owes you',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + to record one',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            for (final debt in activeList) _DebtCard(debt: debt),
            if (settledList.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Settled',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
              ),
              for (final debt in settledList) _DebtCard(debt: debt),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

class _DebtCard extends ConsumerWidget {
  const _DebtCard({required this.debt});

  final Debt debt;

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _dueLabel() {
    if (debt.isSettled) return 'Settled';
    final days = debt.daysUntilDue();
    if (days < 0) {
      final overdue = -days;
      return overdue == 1 ? '1 day overdue' : '$overdue days overdue';
    }
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in $days days';
  }

  Future<void> _toggleSettled(BuildContext context, WidgetRef ref) async {
    final repository = await ref.read(debtRepositoryProvider.future);
    if (debt.isSettled) {
      await repository.unsettle(debt.id!);
    } else {
      await repository.settle(debt.id!);
    }
    ref.invalidate(activeDebtsProvider);
    ref.invalidate(settledDebtsProvider);
    ref.invalidate(debtTotalsProvider);
    ref.invalidate(overdueDebtsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = debt.isOverdue ? AppColors.rose : AppColors.muted;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => showDebtSheet(context, debt: debt),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.personName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            decoration: debt.isSettled
                                ? TextDecoration.lineThrough
                                : null,
                            color: debt.isSettled ? AppColors.muted : null,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      debt.note?.isNotEmpty == true
                          ? '${debt.note}  ·  ${_formatDate(debt.dueDate)}'
                          : _formatDate(debt.dueDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dueLabel(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: accent,
                            fontWeight: debt.isOverdue
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'RM ${(debt.amountCents / 100).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: debt.isSettled ? AppColors.muted : null,
                      decoration:
                          debt.isSettled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => _toggleSettled(context, ref),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      debt.isSettled ? 'Reopen' : 'Settle',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}