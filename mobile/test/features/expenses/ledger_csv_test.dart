import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/expenses/domain/ledger_csv.dart';
import 'package:oweloop/features/expenses/domain/expense_models.dart';
import 'package:oweloop/features/expenses/domain/exact_money.dart';

void main() {
  test('CSV preserves bigint amounts, quotes, newlines and void status', () {
    final text = LedgerCsv.expenses([
      ExpenseRecord(
        id: 'expense',
        groupId: 'group',
        description: 'Dinner, "shared"\nnext line',
        total: const ExactMoney(
          currencyCode: 'AUD',
          minorUnits: MoneyMath.maxMinorUnits,
        ),
        occurredAt: DateTime.utc(2026),
        status: ExpenseStatus.voided,
      ),
    ]);
    expect(text, contains('9223372036854775807'));
    expect(text, contains('""shared""'));
    expect(text, contains('"voided"'));
    expect(text, contains('\r\n'));
  });
  test(
    'CSV escapes spreadsheet formulas without evaluating financial values',
    () {
      for (final description in [
        '=1+1',
        '+SUM(1,2)',
        '-cmd',
        '@SUM(1)',
        '  =SUM(1,2)',
        '\tformula',
      ]) {
        final text = LedgerCsv.expenses([
          ExpenseRecord(
            id: 'expense',
            groupId: 'group',
            description: description,
            total: const ExactMoney(currencyCode: 'JPY', minorUnits: 1),
            occurredAt: DateTime.utc(2026),
            status: ExpenseStatus.posted,
          ),
        ]);
        expect(text, contains('"\'$description"'));
      }
    },
  );
}
