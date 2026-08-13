import 'exact_money.dart';

enum ExpenseStatus {
  draft,
  posted,
  voided;

  factory ExpenseStatus.fromDatabase(Object? value) {
    return switch (value) {
      'posted' => ExpenseStatus.posted,
      'voided' => ExpenseStatus.voided,
      _ => ExpenseStatus.draft,
    };
  }

  String get label => switch (this) {
    ExpenseStatus.draft => 'Draft',
    ExpenseStatus.posted => 'Posted',
    ExpenseStatus.voided => 'Voided',
  };
}

class ExpensePayer {
  const ExpensePayer({
    required this.memberId,
    required this.displayName,
    required this.amount,
  });

  final String memberId;
  final String displayName;
  final ExactMoney amount;

  factory ExpensePayer.fromMap(
    Map<String, dynamic> map, {
    required String currencyCode,
  }) {
    return ExpensePayer(
      memberId: map['group_member_id'] as String,
      displayName: _memberDisplayName(map),
      amount: ExactMoney(
        currencyCode: currencyCode,
        minorUnits: map['amount_minor'] as int,
      ),
    );
  }
}

class ExpenseSplit {
  const ExpenseSplit({
    required this.memberId,
    required this.displayName,
    required this.amount,
  });

  final String memberId;
  final String displayName;
  final ExactMoney amount;

  factory ExpenseSplit.fromMap(
    Map<String, dynamic> map, {
    required String currencyCode,
  }) {
    return ExpenseSplit(
      memberId: map['group_member_id'] as String,
      displayName: _memberDisplayName(map),
      amount: ExactMoney(
        currencyCode: currencyCode,
        minorUnits: map['amount_minor'] as int,
      ),
    );
  }
}

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.groupId,
    required this.description,
    required this.total,
    required this.occurredAt,
    required this.status,
    this.payers = const [],
    this.splits = const [],
  });

  final String id;
  final String groupId;
  final String description;
  final ExactMoney total;
  final DateTime occurredAt;
  final ExpenseStatus status;
  final List<ExpensePayer> payers;
  final List<ExpenseSplit> splits;

  factory ExpenseRecord.fromMap(
    Map<String, dynamic> map, {
    String? currencyCode,
  }) {
    final resolvedCurrencyCode = currencyCode ?? _currencyCodeFrom(map);
    if (resolvedCurrencyCode == null) {
      throw const FormatException('The expense currency is unavailable.');
    }

    final payerRows = _mapList(map['expense_payers']);
    final splitRows = _mapList(map['expense_splits']);
    return ExpenseRecord(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      description: map['description'] as String,
      total: ExactMoney(
        currencyCode: resolvedCurrencyCode,
        minorUnits: map['total_amount_minor'] as int,
      ),
      occurredAt: _dateTimeFrom(map['occurred_at']),
      status: ExpenseStatus.fromDatabase(map['status']),
      payers: payerRows
          .map(
            (row) =>
                ExpensePayer.fromMap(row, currencyCode: resolvedCurrencyCode),
          )
          .toList(),
      splits: splitRows
          .map(
            (row) =>
                ExpenseSplit.fromMap(row, currencyCode: resolvedCurrencyCode),
          )
          .toList(),
    );
  }
}

class ExpenseCreationInput {
  const ExpenseCreationInput({
    required this.groupId,
    required this.description,
    required this.total,
    required this.occurredAt,
    this.payers = const [],
    this.splits = const [],
    this.splitMethod = SplitMethod.equal,
    this.payerMemberId,
    this.participantMemberIds = const [],
  });

  final String groupId;
  final String description;
  final ExactMoney total;
  final DateTime occurredAt;
  final List<ExpenseAllocation> payers;
  final List<ExpenseAllocation> splits;
  final SplitMethod splitMethod;

  /// Temporary compatibility fields for an equal, one-payer draft.
  /// All new callers should pass exact [payers] and [splits].
  final String? payerMemberId;
  final List<String> participantMemberIds;

  String get trimmedDescription => description.trim();

  List<ExpenseAllocation> get resolvedPayers => payers.isNotEmpty
      ? payers
      : payerMemberId == null
      ? const []
      : [
          ExpenseAllocation(
            memberId: payerMemberId!,
            amountMinor: total.minorUnits,
          ),
        ];

  List<ExpenseAllocation> get resolvedSplits => splits.isNotEmpty
      ? splits
      : participantMemberIds.isEmpty
      ? const []
      : EqualSplitPreview.forParticipants(
              total: total,
              participantMemberIds: participantMemberIds,
            ).shares
            .map(
              (share) => ExpenseAllocation(
                memberId: share.memberId,
                amountMinor: share.amount.minorUnits,
              ),
            )
            .toList();
}

enum SplitMethod {
  equal,
  exact,
  percentage,
  shares;

  String get label => switch (this) {
    SplitMethod.equal => 'Equal',
    SplitMethod.exact => 'Exact amounts',
    SplitMethod.percentage => 'Percentage',
    SplitMethod.shares => 'Shares',
  };

  String get helper => switch (this) {
    SplitMethod.equal =>
      'Divide the total evenly with a stable remainder rule.',
    SplitMethod.exact => 'Enter each member’s exact amount.',
    SplitMethod.percentage =>
      'Enter whole basis points; the total must be exactly 100.00%.',
    SplitMethod.shares => 'Enter positive whole-number weights.',
  };
}

class ExpenseAllocation {
  const ExpenseAllocation({required this.memberId, required this.amountMinor});

  final String memberId;
  final int amountMinor;
}

class SplitAllocationException implements Exception {
  const SplitAllocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SplitAllocationCalculator {
  const SplitAllocationCalculator._();

  static List<ExpenseAllocation> equal({
    required int totalMinor,
    required Iterable<String> memberIds,
  }) => _proportional(
    totalMinor: totalMinor,
    valuesByMemberId: {for (final memberId in memberIds) memberId: 1},
    denominator: memberIds.length,
    label: 'participants',
  );

  static List<ExpenseAllocation> exact({
    required int totalMinor,
    required Map<String, int> amountsByMemberId,
  }) {
    _requirePositiveTotal(totalMinor);
    if (amountsByMemberId.isEmpty) {
      throw const SplitAllocationException('Select at least one participant.');
    }
    final total = amountsByMemberId.values.fold(0, (sum, value) => sum + value);
    if (amountsByMemberId.values.any((value) => value < 0)) {
      throw const SplitAllocationException('Split amounts cannot be negative.');
    }
    if (total != totalMinor) {
      throw const SplitAllocationException(
        'Split amounts must equal the expense total.',
      );
    }
    return _ordered(amountsByMemberId);
  }

  static List<ExpenseAllocation> percentages({
    required int totalMinor,
    required Map<String, int> basisPointsByMemberId,
  }) {
    final totalBasisPoints = basisPointsByMemberId.values.fold(
      0,
      (sum, value) => sum + value,
    );
    if (basisPointsByMemberId.values.any((value) => value < 0)) {
      throw const SplitAllocationException('Percentages cannot be negative.');
    }
    if (totalBasisPoints != 10000) {
      throw const SplitAllocationException(
        'Percentages must total exactly 100.00%.',
      );
    }
    return _proportional(
      totalMinor: totalMinor,
      valuesByMemberId: basisPointsByMemberId,
      denominator: 10000,
      label: 'percentages',
    );
  }

  static List<ExpenseAllocation> shares({
    required int totalMinor,
    required Map<String, int> sharesByMemberId,
  }) {
    if (sharesByMemberId.values.any((value) => value <= 0)) {
      throw const SplitAllocationException(
        'Each selected member needs at least one share.',
      );
    }
    final totalShares = sharesByMemberId.values.fold(
      0,
      (sum, value) => sum + value,
    );
    return _proportional(
      totalMinor: totalMinor,
      valuesByMemberId: sharesByMemberId,
      denominator: totalShares,
      label: 'shares',
    );
  }

  static List<ExpenseAllocation> _proportional({
    required int totalMinor,
    required Map<String, int> valuesByMemberId,
    required int denominator,
    required String label,
  }) {
    _requirePositiveTotal(totalMinor);
    if (valuesByMemberId.isEmpty || denominator <= 0) {
      throw SplitAllocationException('Select valid $label.');
    }
    final orderedIds = valuesByMemberId.keys.toList()..sort();
    if (orderedIds.length != valuesByMemberId.length) {
      throw SplitAllocationException('Selected $label must be unique.');
    }
    final initialAmounts = <String, int>{
      for (final memberId in orderedIds)
        memberId: totalMinor * valuesByMemberId[memberId]! ~/ denominator,
    };
    final allocated = initialAmounts.values.fold(
      0,
      (sum, value) => sum + value,
    );
    final remainder = totalMinor - allocated;
    for (var index = 0; index < remainder; index += 1) {
      final memberId = orderedIds[index % orderedIds.length];
      initialAmounts[memberId] = initialAmounts[memberId]! + 1;
    }
    return _ordered(initialAmounts);
  }

  static List<ExpenseAllocation> _ordered(Map<String, int> amounts) {
    final orderedIds = amounts.keys.toList()..sort();
    return [
      for (final memberId in orderedIds)
        ExpenseAllocation(memberId: memberId, amountMinor: amounts[memberId]!),
    ];
  }

  static void _requirePositiveTotal(int totalMinor) {
    if (totalMinor <= 0) {
      throw const SplitAllocationException(
        'Expense total must be greater than zero.',
      );
    }
  }
}

class EqualSplitShare {
  const EqualSplitShare({required this.memberId, required this.amount});

  final String memberId;
  final ExactMoney amount;
}

class EqualSplitPreview {
  const EqualSplitPreview({required this.total, required this.shares});

  final ExactMoney total;
  final List<EqualSplitShare> shares;

  factory EqualSplitPreview.forParticipants({
    required ExactMoney total,
    required Iterable<String> participantMemberIds,
  }) {
    final participantIds = participantMemberIds.toList();
    final orderedParticipantIds = participantIds.toSet().toList()..sort();
    if (orderedParticipantIds.isEmpty ||
        orderedParticipantIds.length != participantIds.length) {
      throw ArgumentError('Participants must be unique and non-empty.');
    }

    final allocations = SplitAllocationCalculator.equal(
      totalMinor: total.minorUnits,
      memberIds: orderedParticipantIds,
    );
    return EqualSplitPreview(
      total: total,
      shares: [
        for (final allocation in allocations)
          EqualSplitShare(
            memberId: allocation.memberId,
            amount: ExactMoney(
              currencyCode: total.currencyCode,
              minorUnits: allocation.amountMinor,
            ),
          ),
      ],
    );
  }
}

String _memberDisplayName(Map<String, dynamic> map) {
  final member = map['group_members'];
  if (member is Map) {
    return member['display_name'] as String? ?? 'Member';
  }
  return 'Member';
}

String? _currencyCodeFrom(Map<String, dynamic> map) {
  final group = map['groups'];
  if (group is Map) {
    return group['currency_code'] as String?;
  }
  return map['currency_code'] as String?;
}

DateTime _dateTimeFrom(Object? value) {
  return switch (value) {
    DateTime dateTime => dateTime,
    String value => DateTime.parse(value),
    _ => throw const FormatException('The expense date is unavailable.'),
  };
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map((row) => Map<String, dynamic>.from(row as Map)).toList();
}
