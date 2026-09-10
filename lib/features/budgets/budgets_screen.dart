import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/core/theme/app_colors.dart';
import 'package:wangku/data/models/budget.dart';
import 'package:wangku/state/index.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(currentMonthProvider);
    final statuses = ref.watch(budgetStatusesProvider(month));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        centerTitle: true,
        elevation: 0,
      ),
      body: statuses.when(
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Set a monthly limit for any category. You will be warned '
                'once spending reaches 90% of the limit.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
              ),
            ),
            for (final status in list)
              _BudgetRow(
                status: status,
                onTap: () => _editLimit(context, ref, status, month),
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Future<void> _editLimit(
    BuildContext context,
    WidgetRef ref,
    BudgetStatus status,
    DateTime month,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SetLimitSheet(status: status, month: month),
    );

    if (saved == true) {
      ref.invalidate(budgetStatusesProvider);
      ref.invalidate(budgetWarningsProvider);
    }
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.status, required this.onTap});

  final BudgetStatus status;
  final VoidCallback onTap;

  Color _barColor() {
    if (status.isOverLimit) return AppColors.rose;
    if (status.isNearLimit) return const Color(0xFFE0A458);
    return AppColors.coral;
  }

  @override
  Widget build(BuildContext context) {
    final spent = 'RM ${(status.spentCents / 100).toStringAsFixed(2)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
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
                      status.categoryName,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (status.hasLimit)
                    Text(
                      '$spent of RM ${(status.limitCents! / 100).toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Text(
                      'No limit set',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                    ),
                ],
              ),
              if (status.hasLimit) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: status.ratio.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: AppColors.line,
                    valueColor: AlwaysStoppedAnimation(_barColor()),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  status.isOverLimit
                      ? 'Over by RM ${(-status.remainingCents / 100).toStringAsFixed(2)}'
                      : 'RM ${(status.remainingCents / 100).toStringAsFixed(2)} left',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: status.isOverLimit
                            ? AppColors.rose
                            : AppColors.muted,
                      ),
                ),
              ] else if (status.spentCents > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '$spent spent this month',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
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

class _SetLimitSheet extends ConsumerStatefulWidget {
  const _SetLimitSheet({required this.status, required this.month});

  final BudgetStatus status;
  final DateTime month;

  @override
  ConsumerState<_SetLimitSheet> createState() => _SetLimitSheetState();
}

class _SetLimitSheetState extends ConsumerState<_SetLimitSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _limitController;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _limitController = TextEditingController(
      text: widget.status.hasLimit
          ? (widget.status.limitCents! / 100).toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  int? _parseCents(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value <= 0) return null;
    return (value * 100).round();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final repository = await ref.read(budgetRepositoryProvider.future);
      await repository.setLimit(
        categoryId: widget.status.categoryId,
        month: widget.month,
        limitCents: _parseCents(_limitController.text)!,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      setState(() {
        _saving = false;
        _saveError = error.toString();
      });
    }
  }

  Future<void> _clear() async {
    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final repository = await ref.read(budgetRepositoryProvider.future);
      await repository.clearLimit(
        categoryId: widget.status.categoryId,
        month: widget.month,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      setState(() {
        _saving = false;
        _saveError = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.status.categoryName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Monthly limit for ${Budget.periodFor(widget.month)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _limitController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Limit',
                    prefixText: 'RM ',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a limit';
                    }
                    if (_parseCents(value) == null) {
                      return 'Enter an amount greater than zero';
                    }
                    return null;
                  },
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: 12),
                  Text(_saveError!, style: TextStyle(color: AppColors.rose)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save limit'),
                ),
                if (widget.status.hasLimit) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _saving ? null : _clear,
                    child: Text(
                      'Remove limit',
                      style: TextStyle(color: AppColors.rose),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}