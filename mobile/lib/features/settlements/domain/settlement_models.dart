import '../../expenses/domain/exact_money.dart';

class SettlementRecord {
  const SettlementRecord({
    required this.id,
    required this.groupId,
    required this.payingMemberId,
    required this.payingMemberName,
    required this.receivingMemberId,
    required this.receivingMemberName,
    required this.amount,
    required this.settledAt,
    required this.isVoided,
    this.voidedAt,
  });

  final String id;
  final String groupId;
  final String payingMemberId;
  final String payingMemberName;
  final String receivingMemberId;
  final String receivingMemberName;
  final ExactMoney amount;
  final DateTime settledAt;
  final bool isVoided;
  final DateTime? voidedAt;

  factory SettlementRecord.fromMap(
    Map<String, dynamic> map, {
    required String groupId,
    required String currencyCode,
  }) {
    return SettlementRecord(
      id: map['settlement_id'] as String,
      groupId: groupId,
      payingMemberId: map['paying_member_id'] as String,
      payingMemberName: map['paying_member_name'] as String,
      receivingMemberId: map['receiving_member_id'] as String,
      receivingMemberName: map['receiving_member_name'] as String,
      amount: ExactMoney(
        currencyCode: currencyCode,
        minorUnits: _minorUnitsFrom(map['amount_minor']),
      ),
      settledAt: _dateTimeFrom(map['settled_at']),
      isVoided: map['is_voided'] as bool? ?? false,
      voidedAt: _nullableDateTimeFrom(map['voided_at']),
    );
  }

  String get statement => '$payingMemberName paid $receivingMemberName';
}

class SettlementCreationInput {
  const SettlementCreationInput({
    required this.groupId,
    required this.payingMemberId,
    required this.receivingMemberId,
    required this.amount,
    required this.settledAt,
  });

  final String groupId;
  final String payingMemberId;
  final String receivingMemberId;
  final ExactMoney amount;
  final DateTime settledAt;
}

class SettlementDraft {
  const SettlementDraft({
    required this.payingMemberId,
    required this.receivingMemberId,
    required this.amount,
  });

  final String payingMemberId;
  final String receivingMemberId;
  final ExactMoney amount;
}

int _minorUnitsFrom(Object? value) => switch (value) {
  int amount => amount,
  String amount =>
    int.tryParse(amount) ??
        (throw const FormatException('The settlement amount is unavailable.')),
  _ => throw const FormatException('The settlement amount is unavailable.'),
};

DateTime _dateTimeFrom(Object? value) => switch (value) {
  DateTime value => value,
  String value => DateTime.parse(value),
  _ => throw const FormatException('The settlement date is unavailable.'),
};

DateTime? _nullableDateTimeFrom(Object? value) => switch (value) {
  null => null,
  _ => _dateTimeFrom(value),
};
