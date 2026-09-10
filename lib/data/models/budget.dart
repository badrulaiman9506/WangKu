/// A spending limit for one category in one month.
///
/// [period] is the month the limit applies to, stored as 'YYYY-MM' so a
/// budget is naturally unique per category per month and sorts by text.
class Budget {
  const Budget({
    this.id,
    required this.categoryId,
    required this.period,
    required this.limitCents,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int categoryId;
  final String period;
  final int limitCents;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Convenience constructor for a new limit. Timestamps are set here so
  /// a caller can build a valid object without touching the database.
  factory Budget.create({
    required int categoryId,
    required DateTime month,
    required int limitCents,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return Budget(
      categoryId: categoryId,
      period: periodFor(month),
      limitCents: limitCents,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  /// Formats a date as the 'YYYY-MM' period string used by the table.
  static String periodFor(DateTime month) {
    final paddedMonth = month.month.toString().padLeft(2, '0');
    return '${month.year}-$paddedMonth';
  }

  bool get isPersisted => id != null;

  Budget copyWith({
    int? id,
    int? categoryId,
    String? period,
    int? limitCents,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      period: period ?? this.period,
      limitCents: limitCents ?? this.limitCents,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory Budget.fromMap(Map<String, Object?> map) => Budget(
        id: map['id'] as int?,
        categoryId: map['category_id'] as int,
        period: map['period'] as String,
        limitCents: map['limit_cents'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'category_id': categoryId,
        'period': period,
        'limit_cents': limitCents,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  String toString() =>
      'Budget(category: $categoryId, period: $period, cents: $limitCents)';
}

/// A category's limit paired with what has been spent against it, which
/// is what every budget screen actually needs to show.
class BudgetStatus {
  const BudgetStatus({
    required this.categoryId,
    required this.categoryName,
    required this.limitCents,
    required this.spentCents,
  });

  final int categoryId;
  final String categoryName;

  /// Null when no budget has been set for this category this month.
  final int? limitCents;
  final int spentCents;

  bool get hasLimit => limitCents != null && limitCents! > 0;

  /// Spending as a fraction of the limit. Returns 0 when no limit is set,
  /// so callers can sort or compare without a null guard.
  double get ratio {
    if (!hasLimit) return 0;
    return spentCents / limitCents!;
  }

  /// The 90% threshold from Objective 2.
  bool get isNearLimit => hasLimit && ratio >= 0.9 && ratio < 1.0;

  bool get isOverLimit => hasLimit && ratio >= 1.0;

  int get remainingCents {
    if (!hasLimit) return 0;
    return limitCents! - spentCents;
  }
}