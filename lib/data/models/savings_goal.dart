/// Something the user is saving toward.
///
/// The table stores a target and a date but no running balance, because
/// the app tracks spending rather than income and has no way to know what
/// has actually been set aside. Progress is therefore expressed as time
/// remaining and the amount per week needed to arrive on time.
class SavingsGoal {
  const SavingsGoal({
    this.id,
    required this.title,
    required this.targetCents,
    required this.targetDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String title;
  final int targetCents;
  final DateTime targetDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Convenience constructor for a new goal. Timestamps are set here so a
  /// caller can build a valid object without touching the database.
  factory SavingsGoal.create({
    required String title,
    required int targetCents,
    required DateTime targetDate,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return SavingsGoal(
      title: title.trim(),
      targetCents: targetCents,
      targetDate: targetDate,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  bool get isPersisted => id != null;

  /// Whole days from today until the target date. Negative once the date
  /// has passed, so callers can distinguish overdue from due today.
  int daysRemaining({DateTime? from}) {
    final today = from ?? DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return end.difference(start).inDays;
  }

  bool get isPast => daysRemaining() < 0;

  bool get isDueToday => daysRemaining() == 0;

  /// How much needs to be set aside each week to reach the target on
  /// time. Returns the full target once the date has passed or is within
  /// a week, since there is no longer a weekly figure that makes sense.
  int weeklyAmountCents({DateTime? from}) {
    final days = daysRemaining(from: from);
    if (days <= 7) return targetCents;
    final weeks = days / 7;
    return (targetCents / weeks).round();
  }

  SavingsGoal copyWith({
    int? id,
    String? title,
    int? targetCents,
    DateTime? targetDate,
    DateTime? updatedAt,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      targetCents: targetCents ?? this.targetCents,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory SavingsGoal.fromMap(Map<String, Object?> map) => SavingsGoal(
        id: map['id'] as int?,
        title: map['title'] as String,
        targetCents: map['target_cents'] as int,
        targetDate: DateTime.parse(map['target_date'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'target_cents': targetCents,
        'target_date': targetDate.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  String toString() =>
      'SavingsGoal(id: $id, title: $title, cents: $targetCents)';
}

/// Sort options for the goals list.
enum SavingsGoalSort {
  soonestFirst,
  largestFirst,
  newestFirst,
}