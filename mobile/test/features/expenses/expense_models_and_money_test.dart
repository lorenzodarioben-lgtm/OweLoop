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

  group('SplitAllocationCalculator', () {
    test('keeps one minor unit exact across three equal participants', () {
      final allocations = SplitAllocationCalculator.equal(
        totalMinor: 1,
        memberIds: const ['member-c', 'member-a', 'member-b'],
      );

      expect(allocations.map((allocation) => allocation.amountMinor), [
        1,
        0,
        0,
      ]);
    });

    test('accepts exact allocations only when their integer sum matches', () {
      expect(
        SplitAllocationCalculator.exact(
          totalMinor: 3333,
          amountsByMemberId: const {'member-b': 833, 'member-a': 2500},
        ).map((allocation) => allocation.amountMinor),
        [2500, 833],
      );
      expect(
        () => SplitAllocationCalculator.exact(
          totalMinor: 1000,
          amountsByMemberId: const {'member-a': 999},
        ),
        throwsA(isA<SplitAllocationException>()),
      );
    });

    test('converts basis points without using floating point', () {
      final allocations = SplitAllocationCalculator.percentages(
        totalMinor: 1000,
        basisPointsByMemberId: const {
          'member-c': 3333,
          'member-a': 3333,
          'member-b': 3334,
        },
      );

      expect(allocations.map((allocation) => allocation.amountMinor), [
        334,
        333,
        333,
      ]);
      expect(
        () => SplitAllocationCalculator.percentages(
          totalMinor: 1000,
          basisPointsByMemberId: const {'member-a': 9999},
        ),
        throwsA(isA<SplitAllocationException>()),
      );
    });

    test(
      'allocates shares deterministically for JPY and rejects zero shares',
      () {
        final allocations = SplitAllocationCalculator.shares(
          totalMinor: 100,
          sharesByMemberId: const {'member-b': 1, 'member-a': 2},
        );

        expect(allocations.map((allocation) => allocation.amountMinor), [
          67,
          33,
        ]);
        expect(
          () => SplitAllocationCalculator.shares(
            totalMinor: 100,
            sharesByMemberId: const {'member-a': 0},
          ),
          throwsA(isA<SplitAllocationException>()),
        );
      },
    );

    test('keeps multiple payer allocations as exact source values', () {
      final input = ExpenseCreationInput(
        groupId: 'group-id',
        description: 'Taxi',
        total: ExactMoney(currencyCode: 'USD', minorUnits: 10000),
        occurredAt: DateTime(2026, 8, 2),
        operationId: '00000000-0000-4000-8000-000000000005',
        payers: [
          ExpenseAllocation(memberId: 'member-a', amountMinor: 6000),
          ExpenseAllocation(memberId: 'member-b', amountMinor: 4000),
        ],
        splits: [
          ExpenseAllocation(memberId: 'member-a', amountMinor: 5000),
          ExpenseAllocation(memberId: 'member-b', amountMinor: 5000),
        ],
      );

      expect(
        input.resolvedPayers.fold(0, (sum, payer) => sum + payer.amountMinor),
        10000,
      );
      expect(
        input.resolvedSplits.fold(0, (sum, split) => sum + split.amountMinor),
        10000,
      );
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
