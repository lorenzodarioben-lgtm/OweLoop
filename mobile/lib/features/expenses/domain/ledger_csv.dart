import 'expense_models.dart';
import 'dart:convert';
import '../../settlements/domain/settlement_models.dart';

abstract final class LedgerCsv {
  static String _cell(Object? value) {
    var text = value?.toString() ?? '';
    // Spreadsheet applications may execute formulas even in quoted CSV cells.
    if (RegExp(r'^\s*[=+\-@]|^[\t\r]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  static String _encode(Iterable<List<Object?>> rows) =>
      rows.map((row) => row.map(_cell).join(',')).join('\r\n');
  static String expenses(Iterable<ExpenseRecord> expenses) => _encode([
    [
      'expense_id',
      'occurred_at_utc',
      'description',
      'category_key',
      'currency',
      'amount_minor',
      'status',
      'payers_json',
      'splits_json',
    ],
    ...expenses.map(
      (expense) => [
        expense.id,
        expense.occurredAt.toUtc().toIso8601String(),
        expense.description,
        expense.category?.name ?? '',
        expense.total.currencyCode,
        expense.total.minorUnits.toString(),
        expense.status.name,
        jsonEncode([
          for (final payer in expense.payers)
            {
              'member_id': payer.memberId,
              'name': payer.displayName,
              'amount_minor': payer.amount.minorUnits.toString(),
            },
        ]),
        jsonEncode([
          for (final split in expense.splits)
            {
              'member_id': split.memberId,
              'name': split.displayName,
              'amount_minor': split.amount.minorUnits.toString(),
            },
        ]),
      ],
    ),
  ]);
  static String settlements(Iterable<SettlementRecord> settlements) => _encode([
    [
      'settlement_id',
      'settled_at_utc',
      'payer_member_id',
      'payer',
      'receiver_member_id',
      'receiver',
      'currency',
      'amount_minor',
      'status',
    ],
    ...settlements.map(
      (settlement) => [
        settlement.id,
        settlement.settledAt.toUtc().toIso8601String(),
        settlement.payingMemberId,
        settlement.payingMemberName,
        settlement.receivingMemberId,
        settlement.receivingMemberName,
        settlement.amount.currencyCode,
        settlement.amount.minorUnits.toString(),
        settlement.isVoided ? 'voided' : 'recorded_external_payment',
      ],
    ),
  ]);
}
