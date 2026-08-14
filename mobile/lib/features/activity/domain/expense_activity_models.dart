import '../../expenses/domain/exact_money.dart';

class ExpenseActivityEvent {
  const ExpenseActivityEvent({
    required this.id,
    required this.type,
    required this.occurredAt,
    required this.currencyCode,
    this.memberDisplayName,
    this.amountMinor,
    this.expenseDescription,
  });

  final String id;
  final String type;
  final DateTime occurredAt;
  final String currencyCode;
  final String? memberDisplayName;
  final int? amountMinor;
  final String? expenseDescription;

  ExactMoney? get amount => amountMinor == null
      ? null
      : ExactMoney(currencyCode: currencyCode, minorUnits: amountMinor!);

  String get title => switch (type) {
    'expense_created' => 'Expense created',
    'expense_updated' => 'Expense updated',
    'expense_finalized' => 'Expense posted',
    'expense_voided' => 'Expense voided',
    'payer_added' => 'Payer allocation recorded',
    'payer_updated' => 'Payer allocation updated',
    'payer_removed' => 'Payer allocation removed',
    'split_added' => 'Split allocation recorded',
    'split_updated' => 'Split allocation updated',
    'split_removed' => 'Split allocation removed',
    _ => 'Activity recorded',
  };

  String? get detail => switch (type) {
    'expense_created' || 'expense_updated' =>
      expenseDescription == null || amount == null
          ? null
          : '$expenseDescription · ${amount!.formatted}',
    'payer_added' || 'payer_updated' || 'payer_removed' =>
      memberDisplayName == null || amount == null
          ? null
          : '$memberDisplayName paid ${amount!.formatted}',
    'split_added' || 'split_updated' || 'split_removed' =>
      memberDisplayName == null || amount == null
          ? null
          : '$memberDisplayName owes ${amount!.formatted}',
    _ => null,
  };

  factory ExpenseActivityEvent.fromMap(
    Map<String, dynamic> map, {
    required String currencyCode,
  }) => ExpenseActivityEvent(
    id: map['event_id'] as String,
    type: map['event_type'] as String? ?? 'unknown',
    occurredAt: _dateTimeFrom(map['occurred_at']),
    currencyCode: currencyCode,
    memberDisplayName: map['member_display_name'] as String?,
    amountMinor: _nullableMinor(map['amount_minor']),
    expenseDescription: map['expense_description'] as String?,
  );
}

int? _nullableMinor(Object? value) => switch (value) {
  null => null,
  int value => value,
  String value => int.tryParse(value),
  _ => null,
};

DateTime _dateTimeFrom(Object? value) => switch (value) {
  DateTime value => value,
  String value => DateTime.parse(value),
  _ => throw const FormatException('The activity timestamp is unavailable.'),
};
