/// A single logged expense.
///
/// [amountCents] is always positive. A refund or correction is handled by
/// editing or deleting the original entry, not by storing a negative
/// amount, which keeps every sum in the app a plain addition.
class Expense {
  const Expense({
    this.id,
    required this.amountCents,
    required this.categoryId,
    required this.spentAt,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int amountCents;
  final int categoryId;
  final DateTime spentAt;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Convenience constructor for a brand new entry. Timestamps are set
  /// here rather than in the repository so a caller can build a valid
  /// object without touching the database.
  factory Expense.create({
    required int amountCents,
    required int categoryId,
    DateTime? spentAt,
    String? note,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return Expense(
      amountCents: amountCents,
      categoryId: categoryId,
      spentAt: spentAt ?? timestamp,
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  bool get isPersisted => id != null;

  Expense copyWith({
    int? id,
    int? amountCents,
    int? categoryId,
    DateTime? spentAt,
    String? note,
    bool clearNote = false,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      amountCents: amountCents ?? this.amountCents,
      categoryId: categoryId ?? this.categoryId,
      spentAt: spentAt ?? this.spentAt,
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory Expense.fromMap(Map<String, Object?> map) => Expense(
        id: map['id'] as int?,
        amountCents: map['amount_cents'] as int,
        categoryId: map['category_id'] as int,
        spentAt: DateTime.parse(map['spent_at'] as String),
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'amount_cents': amountCents,
        'category_id': categoryId,
        'spent_at': spentAt.toIso8601String(),
        'note': note,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  String toString() =>
      'Expense(id: $id, cents: $amountCents, category: $categoryId)';
}

/// One row of the monthly summary chart in Objective 3.
class CategoryTotal {
  const CategoryTotal({
    required this.categoryId,
    required this.slug,
    required this.name,
    required this.totalCents,
    required this.entryCount,
  });

  final int categoryId;
  final String slug;
  final String name;
  final int totalCents;
  final int entryCount;

  factory CategoryTotal.fromMap(Map<String, Object?> map) => CategoryTotal(
        categoryId: map['category_id'] as int,
        slug: map['slug'] as String,
        name: map['name'] as String,
        totalCents: (map['total_cents'] as int?) ?? 0,
        entryCount: (map['entry_count'] as int?) ?? 0,
      );
}

/// Sort options behind the segmented control on the expense list screen.
enum ExpenseSort {
  newestFirst,
  oldestFirst,
  category,
  amountHighFirst,
}
