/// Which way the money flows.
enum DebtDirection {
  /// The user owes someone else.
  iOwe,

  /// Someone else owes the user.
  owedToMe;

  /// The value stored in the `direction` column.
  String get dbValue => this == DebtDirection.iOwe ? 'i_owe' : 'owed_to_me';

  static DebtDirection fromDb(String value) {
    return value == 'i_owe' ? DebtDirection.iOwe : DebtDirection.owedToMe;
  }

  String get label =>
      this == DebtDirection.iOwe ? 'I owe' : 'Owed to me';
}

/// Whether a debt is still outstanding.
enum DebtStatus {
  active,
  settled;

  String get dbValue => name;

  static DebtStatus fromDb(String value) {
    return value == 'settled' ? DebtStatus.settled : DebtStatus.active;
  }
}

/// Money owed in either direction, with a due date and an optional
/// reminder.
///
/// [notificationId] is the id used when a reminder is scheduled on the
/// device, stored so the same notification can be cancelled later.
class Debt {
  const Debt({
    this.id,
    required this.direction,
    required this.personName,
    required this.amountCents,
    required this.dueDate,
    this.note,
    this.status = DebtStatus.active,
    this.settledAt,
    this.reminderEnabled = true,
    this.notificationId,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final DebtDirection direction;
  final String personName;
  final int amountCents;
  final DateTime dueDate;
  final String? note;
  final DebtStatus status;
  final DateTime? settledAt;
  final bool reminderEnabled;
  final int? notificationId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Convenience constructor for a new entry. Timestamps are set here so
  /// a caller can build a valid object without touching the database.
  factory Debt.create({
    required DebtDirection direction,
    required String personName,
    required int amountCents,
    required DateTime dueDate,
    String? note,
    bool reminderEnabled = true,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return Debt(
      direction: direction,
      personName: personName.trim(),
      amountCents: amountCents,
      dueDate: dueDate,
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
      reminderEnabled: reminderEnabled,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  bool get isPersisted => id != null;

  bool get isSettled => status == DebtStatus.settled;

  /// Whole days until the due date. Negative once it has passed.
  int daysUntilDue({DateTime? from}) {
    final today = from ?? DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return end.difference(start).inDays;
  }

  /// Past its due date and still outstanding. A settled debt is never
  /// overdue, however old it is.
  bool get isOverdue => !isSettled && daysUntilDue() < 0;

  bool get isDueToday => !isSettled && daysUntilDue() == 0;

  Debt copyWith({
    int? id,
    DebtDirection? direction,
    String? personName,
    int? amountCents,
    DateTime? dueDate,
    String? note,
    bool clearNote = false,
    DebtStatus? status,
    DateTime? settledAt,
    bool clearSettledAt = false,
    bool? reminderEnabled,
    int? notificationId,
    bool clearNotificationId = false,
    DateTime? updatedAt,
  }) {
    return Debt(
      id: id ?? this.id,
      direction: direction ?? this.direction,
      personName: personName ?? this.personName,
      amountCents: amountCents ?? this.amountCents,
      dueDate: dueDate ?? this.dueDate,
      note: clearNote ? null : (note ?? this.note),
      status: status ?? this.status,
      settledAt: clearSettledAt ? null : (settledAt ?? this.settledAt),
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      notificationId: clearNotificationId
          ? null
          : (notificationId ?? this.notificationId),
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory Debt.fromMap(Map<String, Object?> map) => Debt(
        id: map['id'] as int?,
        direction: DebtDirection.fromDb(map['direction'] as String),
        personName: map['person_name'] as String,
        amountCents: map['amount_cents'] as int,
        dueDate: DateTime.parse(map['due_date'] as String),
        note: map['note'] as String?,
        status: DebtStatus.fromDb(map['status'] as String),
        settledAt: map['settled_at'] == null
            ? null
            : DateTime.parse(map['settled_at'] as String),
        reminderEnabled: (map['reminder_enabled'] as int) == 1,
        notificationId: map['notification_id'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'direction': direction.dbValue,
        'person_name': personName,
        'amount_cents': amountCents,
        'due_date': dueDate.toIso8601String(),
        'note': note,
        'status': status.dbValue,
        'settled_at': settledAt?.toIso8601String(),
        'reminder_enabled': reminderEnabled ? 1 : 0,
        'notification_id': notificationId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  String toString() =>
      'Debt(id: $id, ${direction.dbValue}, $personName, cents: $amountCents)';
}

/// Running totals for the debts screen header.
class DebtTotals {
  const DebtTotals({
    required this.iOweCents,
    required this.owedToMeCents,
  });

  final int iOweCents;
  final int owedToMeCents;

  /// Positive when more is owed to the user than the user owes.
  int get netCents => owedToMeCents - iOweCents;
}