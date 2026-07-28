import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/expenses/data/supabase_expenses_repository.dart';
import 'package:oweloop/features/expenses/domain/exact_money.dart';
import 'package:oweloop/features/expenses/domain/expense_models.dart';
import 'package:oweloop/features/expenses/errors/expenses_error_mapper.dart';
import 'package:oweloop/features/expenses/validation/expense_validators.dart';

void main() {
  group('CurrencyRules and ExactMoney', () {
    test('uses explicit currency fraction-digit rules', () {
      expect(CurrencyRules.fractionDigitsFor('USD'), 2);
      expect(CurrencyRules.fractionDigitsFor('JPY'), 0);
      expect(CurrencyRules.fractionDigitsFor('CHF'), isNull);
    });

    test('parses and formats two-decimal money without floating point', () {
      final money = ExactMoney.tryParse(text: '10.25', currencyCode: 'USD');

      expect(money?.minorUnits, 1025);
      expect(money?.formatted, 'USD 10.25');
      expect(
        ExactMoney.formatMinor(currencyCode: 'USD', minorUnits: 5),
        'USD 0.05',
      );
    });

    test('parses and formats zero-decimal JPY amounts', () {
      final money = ExactMoney.tryParse(text: '1200', currencyCode: 'JPY');

      expect(money?.minorUnits, 1200);
      expect(money?.formatted, 'JPY 1200');
      expect(ExactMoney.tryParse(text: '1200.0', currencyCode: 'JPY'), isNull);
    });

    test('rejects malformed and negative input', () {
      expect(ExactMoney.tryParse(text: '1.234', currencyCode: 'USD'), isNull);
      expect(ExactMoney.tryParse(text: '-1.00', currencyCode: 'USD'), isNull);
      expect(ExactMoney.tryParse(text: '10,00', currencyCode: 'USD'), isNull);
      expect(ExpenseValidators.amount('0.00', 'USD'), isNotNull);
      expect(ExpenseValidators.amount('-1.00', 'USD'), isNotNull);
    });
  });

  group('EqualSplitPreview', () {
    test('splits evenly when there is no remainder', () {
      final preview = EqualSplitPreview.forParticipants(
        total: const ExactMoney(currencyCode: 'USD', minorUnits: 900),
        participantMemberIds: const ['member-c', 'member-a', 'member-b'],
      );

      expect(preview.shares.map((share) => share.amount.minorUnits), [
        300,
        300,
        300,
      ]);
    });

    test('allocates remainders in stable ascending member-ID order', () {
      final preview = EqualSplitPreview.forParticipants(
        total: const ExactMoney(currencyCode: 'USD', minorUnits: 1000),
        participantMemberIds: const ['member-c', 'member-a', 'member-b'],
      );

      expect(preview.shares.map((share) => share.memberId), [
        'member-a',
        'member-b',
        'member-c',
      ]);
      expect(preview.shares.map((share) => share.amount.minorUnits), [
        334,
        333,
        333,
      ]);
    });
  });

  test('maps expenses with payer and exact split details', () {
    final expense = ExpenseRecord.fromMap(<String, dynamic>{
      'id': 'expense-id',
      'group_id': 'group-id',
      'description': 'Lunch',
      'total_amount_minor': 1000,
      'occurred_at': '2026-07-29T12:00:00Z',
      'status': 'posted',
      'groups': <String, dynamic>{'currency_code': 'AUD'},
      'expense_payers': <Map<String, dynamic>>[
        <String, dynamic>{
          'group_member_id': 'payer-id',
          'amount_minor': 1000,
          'group_members': <String, dynamic>{'display_name': 'Taylor'},
        },
      ],
      'expense_splits': <Map<String, dynamic>>[
        <String, dynamic>{
          'group_member_id': 'member-id',
          'amount_minor': 500,
          'group_members': <String, dynamic>{'display_name': 'Morgan'},
        },
      ],
    });

    expect(expense.status, ExpenseStatus.posted);
    expect(expense.total.formatted, 'AUD 10.00');
    expect(expense.payers.single.displayName, 'Taylor');
    expect(expense.splits.single.amount.minorUnits, 500);
  });

  test('maps backend failures to safe expense messages', () {
    expect(
      ExpensesErrorMapper.messageFor(
        const ExpensesRepositoryException(
          'Participants must be active members of this group',
        ),
      ),
      'Select valid group participants.',
    );
    expect(
      ExpensesErrorMapper.messageFor(Exception('internal SQL details')),
      'Something went wrong. Please try again.',
    );
  });
}
