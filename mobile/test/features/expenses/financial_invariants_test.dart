import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/expenses/domain/exact_money.dart';
import 'package:oweloop/features/expenses/domain/expense_models.dart';

void main() {
  test('bigint boundaries parse, round-trip and reject without wrapping', () {
    for (final currency in [
      'AUD',
      'CAD',
      'EUR',
      'GBP',
      'JPY',
      'NZD',
      'SGD',
      'USD',
    ]) {
      final maximum = currency == 'JPY'
          ? '9223372036854775807'
          : '92233720368547758.07';
      final excessive = currency == 'JPY'
          ? '9223372036854775808'
          : '92233720368547758.08';
      expect(
        ExactMoney.tryParse(text: maximum, currencyCode: currency)?.minorUnits,
        MoneyMath.maxMinorUnits,
      );
      expect(
        ExactMoney.tryParse(text: excessive, currencyCode: currency),
        isNull,
      );
      expect(
        ExactMoney.tryParse(
          text: '184467440737095516.17',
          currencyCode: currency,
        ),
        isNull,
      );
    }
  });
  test(
    'zero percentages never receive remainders; ties use member identity',
    () {
      for (final total in [1, 3, 101, MoneyMath.maxMinorUnits]) {
        final result = SplitAllocationCalculator.percentages(
          totalMinor: total,
          basisPointsByMemberId: {'a': 0, 'b': 5000, 'c': 5000},
        );
        expect(result.first.amountMinor, 0);
        expect(
          MoneyMath.sum(result.map((a) => a.amountMinor)),
          BigInt.from(total),
        );
      }
    },
  );
  test(
    'randomized weighted allocations preserve sums, quotas and input-order independence',
    () {
      final random = Random(20261024);
      for (var trial = 0; trial < 500; trial++) {
        final weights = {
          for (var i = 0; i < 1 + random.nextInt(60); i++)
            'member-$i': 1 + random.nextInt(100000),
        };
        final total = trial.isEven
            ? MoneyMath.maxMinorUnits - random.nextInt(1000)
            : 1 + random.nextInt(100000);
        final result = SplitAllocationCalculator.shares(
          totalMinor: total,
          sharesByMemberId: weights,
        );
        final reversed = SplitAllocationCalculator.shares(
          totalMinor: total,
          sharesByMemberId: Map.fromEntries(weights.entries.toList().reversed),
        );
        expect(
          result.map((a) => (a.memberId, a.amountMinor)),
          reversed.map((a) => (a.memberId, a.amountMinor)),
        );
        expect(
          MoneyMath.sum(result.map((a) => a.amountMinor)),
          BigInt.from(total),
        );
        final denominator = MoneyMath.sum(weights.values);
        for (final allocation in result) {
          final floor =
              BigInt.from(total) *
              BigInt.from(weights[allocation.memberId]!) ~/
              denominator;
          expect(
            BigInt.from(allocation.amountMinor) - floor,
            anyOf(BigInt.zero, BigInt.one),
          );
        }
      }
    },
  );
  test('large exact allocations and weights cannot overflow validation', () {
    expect(
      () => SplitAllocationCalculator.exact(
        totalMinor: 1,
        amountsByMemberId: {
          'a': MoneyMath.maxMinorUnits,
          'b': MoneyMath.maxMinorUnits,
          'c': 3,
        },
      ),
      throwsA(isA<SplitAllocationException>()),
    );
    final result = SplitAllocationCalculator.shares(
      totalMinor: MoneyMath.maxMinorUnits,
      sharesByMemberId: {
        'a': MoneyMath.maxMinorUnits,
        'b': MoneyMath.maxMinorUnits,
      },
    );
    expect(MoneyMath.sum(result.map((a) => a.amountMinor)), MoneyMath.maximum);
    expect(
      () => SplitAllocationCalculator.equal(
        totalMinor: 10,
        memberIds: ['a', 'a'],
      ),
      throwsA(isA<SplitAllocationException>()),
    );
  });
}
