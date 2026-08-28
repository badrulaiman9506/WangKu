/// A spending category. Rows are seeded on first run and are stable, so
/// [id] can be held in memory for the length of a session.
class Category {
  const Category({
    required this.id,
    required this.slug,
    required this.name,
    required this.sortOrder,
    this.isCustom = false,
  });

  final int id;
  final String slug;
  final String name;
  final int sortOrder;
  final bool isCustom;

  factory Category.fromMap(Map<String, Object?> map) => Category(
        id: map['id'] as int,
        slug: map['slug'] as String,
        name: map['name'] as String,
        sortOrder: map['sort_order'] as int,
        isCustom: (map['is_custom'] as int) == 1,
      );

  Map<String, Object?> toMap() => {
        if (id > 0) 'id': id,
        'slug': slug,
        'name': name,
        'sort_order': sortOrder,
        'is_custom': isCustom ? 1 : 0,
      };

  @override
  String toString() => 'Category($slug)';
}
