import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/balances/domain/balance_models.dart';
import 'package:oweloop/features/expenses/domain/exact_money.dart';
import 'package:oweloop/features/groups/domain/group_models.dart';
import 'package:oweloop/features/repayments/domain/repayment_suggestion_models.dart';

void main() {
  test('creates one exact repayment for a two-party balance', () {
    final suggestions = DebtSimplifier.suggest([
      balance(id: 'alex', name: 'Alex', minorUnits: -1250),
      balance(id: 'blair', name: 'Blair', minorUnits: 1250),
    ]);

    expect(suggestions, hasLength(1));
    expect(suggestions.single.payingMember.groupMemberId, 'alex');
    expect(suggestions.single.receivingMember.groupMemberId, 'blair');
    expect(suggestions.single.amount.currencyCode, 'AUD');
    expect(suggestions.single.amount.minorUnits, 1250);
  });

  test('uses a small deterministic set of repayments for several balances', () {
    final suggestions = DebtSimplifier.suggest([
      balance(id: 'dana', name: 'Dana', minorUnits: -500),
      balance(id: 'alex', name: 'Alex', minorUnits: -300),
      balance(id: 'casey', name: 'Casey', minorUnits: 400),
      balance(id: 'blair', name: 'Blair', minorUnits: 400),
    ]);

    expect(suggestions, hasLength(3));
    expect(
      suggestions.map(
        (suggestion) => (
          payer: suggestion.payingMember.groupMemberId,
          receiver: suggestion.receivingMember.groupMemberId,
          amount: suggestion.amount.minorUnits,
        ),
      ),
      [
        (payer: 'dana', receiver: 'blair', amount: 400),
        (payer: 'dana', receiver: 'casey', amount: 100),
        (payer: 'alex', receiver: 'casey', amount: 300),
      ],
    );
  });

  test('returns no repayments when every member is settled', () {
    expect(
      DebtSimplifier.suggest([
        balance(id: 'alex', name: 'Alex', minorUnits: 0),
        balance(id: 'blair', name: 'Blair', minorUnits: 0),
      ]),
      isEmpty,
    );
  });

  test('preserves guest and removed members in calculated suggestions', () {
    final suggestions = DebtSimplifier.suggest([
      balance(id: 'guest', name: 'Guest', minorUnits: -200, isGuest: true),
      balance(id: 'former', name: 'Former', minorUnits: 200, isRemoved: true),
    ]);

    expect(suggestions.single.payingMember.isGuest, isTrue);
    expect(suggestions.single.receivingMember.isRemoved, isTrue);
    expect(suggestions.single.involvesRemovedMember, isTrue);
  });

  test('keeps JPY whole-unit amounts exact', () {
    final suggestions = DebtSimplifier.suggest([
      balance(id: 'alex', name: 'Alex', minorUnits: -125, currencyCode: 'JPY'),
      balance(id: 'blair', name: 'Blair', minorUnits: 125, currencyCode: 'JPY'),
    ]);

    expect(suggestions.single.amount.formatted, 'JPY 125');
  });

  test('is deterministic regardless of balance result order', () {
    final first = [
      balance(id: 'dana', name: 'Dana', minorUnits: -400),
      balance(id: 'alex', name: 'Alex', minorUnits: -400),
      balance(id: 'casey', name: 'Casey', minorUnits: 400),
      balance(id: 'blair', name: 'Blair', minorUnits: 400),
    ];
    final second = first.reversed.toList();

    expect(
      DebtSimplifier.suggest(
        second,
      ).map((suggestion) => suggestion.statement).toList(),
      DebtSimplifier.suggest(
        first,
      ).map((suggestion) => suggestion.statement).toList(),
    );
  });

  test('rejects inconsistent or mixed-currency balance results', () {
    expect(
      () => DebtSimplifier.suggest([
        balance(id: 'alex', name: 'Alex', minorUnits: -10),
        balance(id: 'blair', name: 'Blair', minorUnits: 9),
      ]),
      throwsFormatException,
    );
    expect(
      () => DebtSimplifier.suggest([
        balance(id: 'alex', name: 'Alex', minorUnits: -10),
        balance(
          id: 'blair',
          name: 'Blair',
          minorUnits: 10,
          currencyCode: 'JPY',
        ),
      ]),
      throwsFormatException,
    );
  });
}

GroupBalance balance({
  required String id,
  required String name,
  required int minorUnits,
  String currencyCode = 'AUD',
  bool isGuest = false,
  bool isRemoved = false,
}) {
  return GroupBalance(
    groupMemberId: id,
    displayName: name,
    role: GroupRole.member,
    isRemoved: isRemoved,
    isGuest: isGuest,
    isCurrentUser: false,
    netBalance: ExactMoney(currencyCode: currencyCode, minorUnits: minorUnits),
  );
}
