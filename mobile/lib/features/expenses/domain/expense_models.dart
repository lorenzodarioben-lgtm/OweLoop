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
    required this.payerMemberId,
    required this.participantMemberIds,
  });

  final String groupId;
  final String description;
  final ExactMoney total;
  final DateTime occurredAt;
  final String payerMemberId;
  final List<String> participantMemberIds;

  String get trimmedDescription => description.trim();
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

    final baseAmount = total.minorUnits ~/ orderedParticipantIds.length;
    final remainder = total.minorUnits % orderedParticipantIds.length;
    return EqualSplitPreview(
      total: total,
      shares: [
        for (var index = 0; index < orderedParticipantIds.length; index += 1)
          EqualSplitShare(
            memberId: orderedParticipantIds[index],
            amount: ExactMoney(
              currencyCode: total.currencyCode,
              minorUnits: baseAmount + (index < remainder ? 1 : 0),
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
