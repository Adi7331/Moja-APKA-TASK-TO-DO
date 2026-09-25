enum BillingCycle { weekly, monthly, quarterly, yearly }

enum CostEntryType { expense, income }

enum CostEntryStatus { planned, paid }

class CostCategory {
  const CostCategory({
    required this.id,
    required this.name,
    this.colorValue = 0xFF2F6FED,
    this.emoji,
    this.createdAt,
    this.updatedAt,
  });

  factory CostCategory.fromStorage(Map<String, dynamic> json) => CostCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF2F6FED,
    emoji: json['emoji'] as String?,
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
  );

  factory CostCategory.fromSupabaseRow(Map<String, dynamic> row) =>
      CostCategory(
        id: row['id'] as String,
        name: row['name'] as String,
        colorValue: (row['color_value'] as num?)?.toInt() ?? 0xFF2F6FED,
        emoji: row['emoji'] as String?,
        createdAt: _date(row['created_at']),
        updatedAt: _date(row['updated_at']),
      );

  final String id;
  final String name;
  final int colorValue;
  final String? emoji;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toStorage() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'emoji': emoji,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };

  Map<String, dynamic> toSupabasePayload(String userId) => {
    'id': id,
    'user_id': userId,
    'name': name,
    'color_value': colorValue,
    'emoji': emoji,
    'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
  };
}

class CostEntry {
  const CostEntry({
    required this.id,
    required this.title,
    required this.amountCents,
    required this.type,
    required this.status,
    required this.occurredAt,
    this.categoryId,
    this.subscriptionId,
    this.note = '',
    this.createdAt,
    this.updatedAt,
  });

  factory CostEntry.fromStorage(Map<String, dynamic> json) => CostEntry(
    id: json['id'] as String,
    title: json['title'] as String,
    amountCents: (json['amountCents'] as num).toInt(),
    type: CostEntryType.values.byName(json['type'] as String),
    status: CostEntryStatus.values.byName(json['status'] as String),
    occurredAt: DateTime.parse(json['occurredAt'] as String),
    categoryId: json['categoryId'] as String?,
    subscriptionId: json['subscriptionId'] as String?,
    note: json['note'] as String? ?? '',
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
  );

  factory CostEntry.fromSupabaseRow(Map<String, dynamic> row) => CostEntry(
    id: row['id'] as String,
    title: row['title'] as String,
    amountCents: (row['amount_cents'] as num).toInt(),
    type: CostEntryType.values.byName(row['entry_type'] as String),
    status: CostEntryStatus.values.byName(row['status'] as String),
    occurredAt: DateTime.parse(row['occurred_at'] as String).toLocal(),
    categoryId: row['category_id'] as String?,
    subscriptionId: row['subscription_id'] as String?,
    note: row['note'] as String? ?? '',
    createdAt: _date(row['created_at']),
    updatedAt: _date(row['updated_at']),
  );

  final String id;
  final String title;
  final int amountCents;
  final CostEntryType type;
  final CostEntryStatus status;
  final DateTime occurredAt;
  final String? categoryId;
  final String? subscriptionId;
  final String note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPaid => status == CostEntryStatus.paid;

  Map<String, dynamic> toStorage() => {
    'id': id,
    'title': title,
    'amountCents': amountCents,
    'type': type.name,
    'status': status.name,
    'occurredAt': occurredAt.toIso8601String(),
    'categoryId': categoryId,
    'subscriptionId': subscriptionId,
    'note': note,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };

  Map<String, dynamic> toSupabasePayload(String userId) => {
    'id': id,
    'user_id': userId,
    'title': title,
    'amount_cents': amountCents,
    'entry_type': type.name,
    'status': status.name,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'category_id': categoryId,
    'subscription_id': subscriptionId,
    'note': note,
    'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
  };
}

class CostSubscription {
  const CostSubscription({
    required this.id,
    required this.name,
    required this.amountCents,
    required this.cycle,
    required this.nextPaymentAt,
    this.categoryId,
    this.reminderDays = const [3, 1],
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  factory CostSubscription.fromStorage(Map<String, dynamic> json) =>
      CostSubscription(
        id: json['id'] as String,
        name: json['name'] as String,
        amountCents: (json['amountCents'] as num).toInt(),
        cycle: BillingCycle.values.byName(json['cycle'] as String),
        nextPaymentAt: DateTime.parse(json['nextPaymentAt'] as String),
        categoryId: json['categoryId'] as String?,
        reminderDays: ((json['reminderDays'] as List?) ?? const [3, 1])
            .map((day) => (day as num).toInt())
            .toList(),
        active: json['active'] as bool? ?? true,
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
      );

  factory CostSubscription.fromSupabaseRow(Map<String, dynamic> row) =>
      CostSubscription(
        id: row['id'] as String,
        name: row['name'] as String,
        amountCents: (row['amount_cents'] as num).toInt(),
        cycle: BillingCycle.values.byName(row['billing_cycle'] as String),
        nextPaymentAt: DateTime.parse(row['next_payment_at'] as String)
            .toLocal(),
        categoryId: row['category_id'] as String?,
        reminderDays: ((row['reminder_days'] as List?) ?? const [3, 1])
            .map((day) => (day as num).toInt())
            .toList(),
        active: row['active'] as bool? ?? true,
        createdAt: _date(row['created_at']),
        updatedAt: _date(row['updated_at']),
      );

  final String id;
  final String name;
  final int amountCents;
  final BillingCycle cycle;
  final DateTime nextPaymentAt;
  final String? categoryId;
  final List<int> reminderDays;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get monthlyEquivalentCents => switch (cycle) {
    BillingCycle.weekly => (amountCents * 52 + 6) ~/ 12,
    BillingCycle.monthly => amountCents,
    BillingCycle.quarterly => (amountCents + 1) ~/ 3,
    BillingCycle.yearly => (amountCents + 6) ~/ 12,
  };

  Map<String, dynamic> toStorage() => {
    'id': id,
    'name': name,
    'amountCents': amountCents,
    'cycle': cycle.name,
    'nextPaymentAt': nextPaymentAt.toIso8601String(),
    'categoryId': categoryId,
    'reminderDays': reminderDays,
    'active': active,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };

  Map<String, dynamic> toSupabasePayload(String userId) => {
    'id': id,
    'user_id': userId,
    'name': name,
    'amount_cents': amountCents,
    'billing_cycle': cycle.name,
    'next_payment_at': nextPaymentAt.toUtc().toIso8601String(),
    'category_id': categoryId,
    'reminder_days': reminderDays,
    'active': active,
    'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is CostSubscription &&
      other.id == id &&
      other.name == name &&
      other.amountCents == amountCents &&
      other.cycle == cycle &&
      other.nextPaymentAt == nextPaymentAt &&
      other.categoryId == categoryId &&
      other.active == active &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      _sameDays(other.reminderDays, reminderDays);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    amountCents,
    cycle,
    nextPaymentAt,
    categoryId,
    Object.hashAll(reminderDays),
    active,
    createdAt,
    updatedAt,
  );
}

DateTime nextBillingDate(DateTime date, BillingCycle cycle) {
  if (cycle == BillingCycle.weekly) return _addCalendarDays(date, 7);
  final monthsToAdd = switch (cycle) {
    BillingCycle.weekly => 0,
    BillingCycle.monthly => 1,
    BillingCycle.quarterly => 3,
    BillingCycle.yearly => 12,
  };
  final monthIndex = date.month - 1 + monthsToAdd;
  final year = date.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final day = date.day.clamp(1, DateTime(year, month + 1, 0).day);
  return date.isUtc
      ? DateTime.utc(
          year,
          month,
          day,
          date.hour,
          date.minute,
          date.second,
          date.millisecond,
          date.microsecond,
        )
      : DateTime(
          year,
          month,
          day,
          date.hour,
          date.minute,
          date.second,
          date.millisecond,
          date.microsecond,
        );
}

DateTime _addCalendarDays(DateTime date, int days) => date.isUtc
    ? DateTime.utc(
        date.year,
        date.month,
        date.day + days,
        date.hour,
        date.minute,
        date.second,
        date.millisecond,
        date.microsecond,
      )
    : DateTime(
        date.year,
        date.month,
        date.day + days,
        date.hour,
        date.minute,
        date.second,
        date.millisecond,
        date.microsecond,
      );

DateTime? _date(dynamic value) =>
    value is String ? DateTime.parse(value) : null;

bool _sameDays(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
