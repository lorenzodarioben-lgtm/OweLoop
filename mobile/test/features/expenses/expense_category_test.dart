import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/expenses/domain/expense_category.dart';
import 'package:oweloop/features/expenses/domain/expense_models.dart';
import 'package:oweloop/features/expenses/domain/ledger_csv.dart';
import 'package:oweloop/core/operations/history_page.dart';

void main() {
  test('stable category keys survive records, filters and exports', () {
    for (final category in ExpenseCategory.values) {
      final record = ExpenseRecord.fromMap({
        'id': 'expense',
        'group_id': 'group',
        'description': 'Dinner',
        'currency_code': 'AUD',
        'total_amount_minor': 101,
        'occurred_at': '2026-10-01T00:00:00Z',
        'status': 'posted',
        'category_key': category.name,
      });
      expect(record.category, category);
      expect(record.categoryLabel, category.label);
      expect(LedgerCsv.expenses([record]), contains('"${category.name}"'));
      expect(
        ExpenseHistoryFilter(
          categoryKey: category.name,
        ).params['p_category_key'],
        category.name,
      );
    }
  });
  test('legacy uncategorized and unknown keys have explicit behavior', () {
    expect(ExpenseCategory.fromKey(null), isNull);
    expect(() => ExpenseCategory.fromKey('arbitrary'), throwsFormatException);
    expect(
      const ExpenseHistoryFilter(categoryKey: '').params['p_category_key'],
      '',
    );
  });
}
