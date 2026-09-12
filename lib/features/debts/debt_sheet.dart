import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/core/theme/app_colors.dart';
import 'package:wangku/data/models/debt.dart';
import 'package:wangku/state/index.dart';

/// Opens the debt sheet. Pass [debt] to edit an existing entry, or
/// [direction] to start a new one on that side. Returns true if anything
/// was saved or deleted.
Future<bool?> showDebtSheet(
  BuildContext context, {
  Debt? debt,
  DebtDirection direction = DebtDirection.iOwe,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DebtSheet(debt: debt, direction: direction),
  );
}

class DebtSheet extends ConsumerStatefulWidget {
  const DebtSheet({
    Key? key,
    this.debt,
    this.direction = DebtDirection.iOwe,
  }) : super(key: key);

  final Debt? debt;
  final DebtDirection direction;

  @override
  ConsumerState<DebtSheet> createState() => _DebtSheetState();
}

class _DebtSheetState extends ConsumerState<DebtSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late DebtDirection _direction;
  late DateTime _dueDate;
  late bool _reminderEnabled;
  bool _saving = false;
  String? _saveError;

  bool get _isEditing => widget.debt != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.debt;

    _nameController = TextEditingController(text: existing?.personName ?? '');
    _amountController = TextEditingController(
      text: existing == null
          ? ''
          : (existing.amountCents / 100).toStringAsFixed(2),
    );
    _noteController = TextEditingController(text: existing?.note ?? '');

    _direction = existing?.direction ?? widget.direction;
    _dueDate =
        existing?.dueDate ?? DateTime.now().add(const Duration(days: 14));
    _reminderEnabled = existing?.reminderEnabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int? _parseCents(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value <= 0) return null;
    return (value * 100).round();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _refreshDebtViews() {
    ref.invalidate(activeDebtsProvider);
    ref.invalidate(settledDebtsProvider);
    ref.invalidate(debtTotalsProvider);
    ref.invalidate(overdueDebtsProvider);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final repository = await ref.read(debtRepositoryProvider.future);
      final cents = _parseCents(_amountController.text)!;
      final note = _noteController.text;

      if (_isEditing) {
        await repository.update(
          widget.debt!.copyWith(
            direction: _direction,
            personName: _nameController.text.trim(),
            amountCents: cents,
            dueDate: _dueDate,
            note: note.trim().isEmpty ? null : note.trim(),
            clearNote: note.trim().isEmpty,
            reminderEnabled: _reminderEnabled,
          ),
        );
      } else {
        await repository.insert(
          Debt.create(
            direction: _direction,
            personName: _nameController.text,
            amountCents: cents,
            dueDate: _dueDate,
            note: note,
            reminderEnabled: _reminderEnabled,
          ),
        );
      }

      _refreshDebtViews();
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
        title: const Text('Delete this record?'),
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
      final repository = await ref.read(debtRepositoryProvider.future);
      await repository.delete(widget.debt!.id!);
      _refreshDebtViews();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      setState(() {
        _saving = false;
        _saveError = error.toString();
      });
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditing ? 'Edit record' : 'New record',
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
                const SizedBox(height: 16),
                SegmentedButton<DebtDirection>(
                  segments: const [
                    ButtonSegment(
                      value: DebtDirection.iOwe,
                      label: Text('I owe'),
                    ),
                    ButtonSegment(
                      value: DebtDirection.owedToMe,
                      label: Text('Owed to me'),
                    ),
                  ],
                  selected: {_direction},
                  onSelectionChanged: (selection) {
                    setState(() => _direction = selection.first);
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Who is this with?',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _amountController,
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
                Text('Due date',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(_formatDate(_dueDate)),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _noteController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _reminderEnabled,
                  onChanged: (value) {
                    setState(() => _reminderEnabled = value);
                  },
                  title: const Text('Remind me'),
                  subtitle: Text(
                    'A reminder on the due date',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                  ),
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
                      : Text(_isEditing ? 'Save changes' : 'Save record'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}