import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/category.dart';

/// Reads the seeded category list. Categories change rarely, so the
/// result is cached for the session and the chip row on the add-expense
/// sheet does not hit the database on every open.
class CategoryRepository {
  CategoryRepository(this._db);

  final Database _db;

  static Future<CategoryRepository> open() async =>
      CategoryRepository(await AppDatabase.instance.database);

  List<Category>? _cache;

  Future<List<Category>> listAll({bool refresh = false}) async {
    if (_cache != null && !refresh) return _cache!;
    final rows = await _db.query('categories', orderBy: 'sort_order ASC');
    return _cache = rows.map(Category.fromMap).toList();
  }

  Future<Category?> findBySlug(String slug) async {
    final all = await listAll();
    for (final category in all) {
      if (category.slug == slug) return category;
    }
    return null;
  }

  Future<Category?> findById(int id) async {
    final all = await listAll();
    for (final category in all) {
      if (category.id == id) return category;
    }
    return null;
  }

  /// The id of the 'other' category, used as the fallback when an entry
  /// has no obvious category.
  Future<int> otherCategoryId() async {
    final other = await findBySlug('other');
    if (other == null) {
      throw StateError('Seed data missing: no "other" category');
    }
    return other.id;
  }
}
