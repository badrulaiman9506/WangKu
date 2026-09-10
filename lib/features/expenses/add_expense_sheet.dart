import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/core/theme/app_colors.dart';
import 'package:wangku/data/models/expense.dart';
import 'package:wangku/state/index.dart';

/// Opens the expense sheet. Pass [expense] to edit an existing entry,
/// omit it to create a new one. Returns true if anything was saved or
/// deleted, so the caller can react if it needs to.
Future<bool?> showAddExpenseSheet(BuildContext context, {Expense? expense}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => AddExpenseSheet(expense: expense),
  );
}

class AddExpenseSheet extends ConsumerStatefulWidget {
  const AddExpenseSheet({Key? key, this.expense}) : super(key: key);

  final Expense? expense;

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  int? _categoryId;
  late DateTime _spentAt;
  bool _saving = false;
  String? _saveError;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.expense;

    _amountController = TextEditingController(
      text: existing == null
          ? ''
          : (existing.amountCents / 100).toStringAsFixed(2),
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
    _categoryId = existing?.categoryId;
    _spentAt = existing?.spentAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Parses "12.50" into 1250. Returns null if the text is not a valid
  /// positive amount, so validation and conversion share one code path.
  int? _parseCents(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value <= 0) return null;
    return (value * 100).round();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _spentAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _spentAt = picked);
    }
  }

  /// Refreshes everything that reads expenses: the list, the monthly
  /// total, the summary chart and the budget warnings, without any of
  /// those screens knowing about this sheet.
  void _refreshExpenseViews() {
    ref.invalidate(expensesProvider);
    ref.invalidate(monthlyTotalCentsProvider);
    ref.invalidate(expensesByMonthProvider);
    ref.invalidate(categoryTotalsProvider);
    ref.invalidate(budgetStatusesProvider);
    ref.invalidate(budgetWarningsProvider);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      setState(() => _saveError = 'Pick a category');
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final repository = await ref.read(expenseRepositoryProvider.future);
      final cents = _parseCents(_amountController.text)!;
      final note = _noteController.text;

      if (_isEditing) {
        await repository.update(
          widget.expense!.copyWith(
            amountCents: cents,
            categoryId: _categoryId,
            spentAt: _spentAt,
            note: note.trim().isEmpty ? null : note.trim(),
            clearNote: note.trim().isEmpty,
          ),
        );
      } else {
        await repository.insert(
          Expense.create(
            amountCents: cents,
            categoryId: _categoryId!,
            spentAt: _spentAt,
            note: note,
          ),
        );
      }

      _refreshExpenseViews();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      setState(() {
        _saving = false;
        _saveError = error.toString();
      });
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this expense?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: AppColors.rose)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final repository = await ref.read(expenseRepositoryProvider.future);
      await repository.delete(widget.expense!.id!);
      _refreshExpenseViews();
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
    final categories = ref.watch(categoriesProvider);
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditing ? 'Edit expense' : 'Add expense',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (_isEditing)
                      IconButton(
                        onPressed: _saving ? null : _confirmDelete,
                        icon: Icon(
                          Icons.delete_outline,
                          color: AppColors.rose,
                        ),
                        tooltip: 'Delete',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  autofocus: !_isEditing,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'RM ',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter an amount';
                    }
                    if (_parseCents(value) == null) {
                      return 'Enter an amount greater than zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text('Category', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                categories.when(
                  data: (list) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in list)
                        ChoiceChip(
                          label: Text(category.name),
                          selected: _categoryId == category.id,
                          onSelected: (_) {
                            setState(() {
                              _categoryId = category.id;
                              _saveError = null;
                            });
                          },
                        ),
                    ],
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(),
                  ),
                  error: (err, stack) => Text('Could not load categories: $err'),
                ),
                const SizedBox(height: 20),
                Text('Date', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(_formatDate(_spentAt)),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _noteController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _saveError!,
                    style: TextStyle(color: AppColors.rose),
                  ),
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
                      : Text(_isEditing ? 'Save changes' : 'Save expense'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}