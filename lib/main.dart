import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'core/utils/money.dart';
import 'data/models/category.dart';
import 'data/models/expense.dart';
import 'data/repositories/category_repository.dart';
import 'data/repositories/expense_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WangKuApp());
}

class WangKuApp extends StatelessWidget {
  const WangKuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wang Ku',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const DatabaseSmokeScreen(),
    );
  }
}

/// Temporary screen. It exists to confirm three things on a real device
/// before any UI is built: the database file is created, the categories
/// are seeded, and an insert followed by a read comes back intact.
/// This gets replaced by the Home screen in the next step.
class DatabaseSmokeScreen extends StatefulWidget {
  const DatabaseSmokeScreen({super.key});

  @override
  State<DatabaseSmokeScreen> createState() => _DatabaseSmokeScreenState();
}

class _DatabaseSmokeScreenState extends State<DatabaseSmokeScreen> {
  late Future<_SmokeResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _run();
  }

  Future<_SmokeResult> _run() async {
    final categories = await CategoryRepository.open();
    final expenses = await ExpenseRepository.open();

    final all = await categories.listAll();
    final food = await categories.findBySlug('food');

    if (await expenses.count() == 0 && food != null) {
      await expenses.insert(
        Expense.create(
          amountCents: 1200,
          categoryId: food.id,
          note: 'Nasi ayam',
        ),
      );
    }

    return _SmokeResult(
      categories: all,
      entryCount: await expenses.count(),
      monthTotalCents: await expenses.monthTotalCents(DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wang Ku')),
      body: FutureBuilder<_SmokeResult>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(AppTheme.s24),
              child: Text(
                'Database failed to open.\n\n${snapshot.error}',
                style: AppTypography.bodyRegular
                    .copyWith(color: AppColors.rose),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final result = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(AppTheme.s20),
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.s24),
                decoration: BoxDecoration(
                  color: AppColors.navy900,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SPENT THIS MONTH',
                      style: AppTypography.label
                          .copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: AppTheme.s8),
                    Text(
                      Money.format(result.monthTotalCents),
                      style: AppTypography.amountHero
                          .copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: AppTheme.s12),
                    Text(
                      '${result.entryCount} entries stored locally',
                      style: AppTypography.caption
                          .copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.s24),
              Text('CATEGORIES SEEDED', style: AppTypography.label),
              const SizedBox(height: AppTheme.s12),
              ...result.categories.map(_categoryTile),
            ],
          );
        },
      ),
    );
  }

  Widget _categoryTile(Category category) {
    final palette = CategoryPalette.of(category.slug);
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.s8),
      padding: const EdgeInsets.all(AppTheme.s12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(palette.icon, size: 20, color: palette.foreground),
          ),
          const SizedBox(width: AppTheme.s12),
          Text(category.name, style: AppTypography.body),
        ],
      ),
    );
  }
}

class _SmokeResult {
  const _SmokeResult({
    required this.categories,
    required this.entryCount,
    required this.monthTotalCents,
  });

  final List<Category> categories;
  final int entryCount;
  final int monthTotalCents;
}
