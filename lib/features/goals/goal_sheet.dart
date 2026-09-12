import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/core/theme/app_colors.dart';
import 'package:wangku/data/models/savings_goal.dart';
import 'package:wangku/state/index.dart';

/// Opens the goal sheet. Pass [goal] to edit an existing one, omit it to
/// create a new one. Returns true if anything was saved or deleted.
Future<bool?> showGoalSheet(BuildContext context, {SavingsGoal? goal}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => GoalSheet(goal: goal),
  );
}

class GoalSheet extends ConsumerStatefulWidget {
  const GoalSheet({Key? key, this.goal}) : super(key: key);

  final SavingsGoal? goal;

  @override
  ConsumerState<GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<GoalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _targetController;

  late DateTime _targetDate;
  bool _saving = false;
  String? _saveError;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.goal;

    _titleController = TextEditingController(text: existing?.title ?? '');
    _targetController = TextEditingController(
      text: existing == null
          ? ''
          : (existing.targetCents / 100).toStringAsFixed(2),
    );
    _targetDate =
        existing?.targetDate ?? DateTime.now().add(const Duration(days: 90));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
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
      initialDate: _targetDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  void _refreshGoalViews() {
    ref.invalidate(savingsGoalsProvider);
    ref.invalidate(upcomingGoalsProvider);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final repository =
          await ref.read(savingsGoalRepositoryProvider.future);
      final cents = _parseCents(_targetController.text)!;
      final title = _titleController.text.trim();

      if (_isEditing) {
        await repository.update(
          widget.goal!.copyWith(
            title: title,
            targetCents: cents,
            targetDate: _targetDate,
          ),
        );
      } else {
        await repository.insert(
          SavingsGoal.create(
            title: title,
            targetCents: cents,
            targetDate: _targetDate,
          ),
        );
      }

      _refreshGoalViews();
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
        title: const Text('Delete this goal?'),
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
      final repository =
          await ref.read(savingsGoalRepositoryProvider.future);
      await repository.delete(widget.goal!.id!);
      _refreshGoalViews();
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
                      _isEditing ? 'Edit goal' : 'New goal',
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
                  controller: _titleController,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'What are you saving for?',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Give the goal a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _targetController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Target amount',
                    prefixText: 'RM ',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a target';
                    }
                    if (_parseCents(value) == null) {
                      return 'Enter an amount greater than zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text('Target date',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(_formatDate(_targetDate)),
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
                      : Text(_isEditing ? 'Save changes' : 'Save goal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}