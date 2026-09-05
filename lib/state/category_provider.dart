import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/data/models/category.dart';
import 'package:wangku/data/repositories/category_repository.dart';

final categoryRepositoryProvider =
    FutureProvider<CategoryRepository>((ref) async {
  return CategoryRepository.open();
});

/// The nine seeded categories, in sort order. Cached by the repository,
/// so this reads the database once per session.
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repository = await ref.watch(categoryRepositoryProvider.future);
  return repository.listAll();
});

/// Category lookup by id, for screens that hold an expense and need its
/// name. Built from the same cached list rather than a second query.
final categoriesByIdProvider = FutureProvider<Map<int, Category>>((ref) async {
  final categories = await ref.watch(categoriesProvider.future);
  return {for (final category in categories) category.id: category};
});