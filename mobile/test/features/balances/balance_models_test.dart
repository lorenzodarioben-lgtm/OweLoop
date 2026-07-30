import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/balances/domain/balance_models.dart';
import 'package:oweloop/features/balances/errors/balances_error_mapper.dart';

import '../../fakes/balances_fakes.dart';

void main() {
  group('GroupBalance', () {
    test('uses exact absolute amounts and clear balance language', () {
      expect(testCurrentOwedBalance.position, BalancePosition.owed);
      expect(testCurrentOwedBalance.absoluteBalance.formatted, 'AUD 30.00');
      expect(
        testCurrentOwedBalance.memberStatement,
        'Taylor is owed AUD 30.00',
      );

      expect(testCurrentOwingBalance.position, BalancePosition.owing);
      expect(testCurrentOwingBalance.absoluteBalance.formatted, 'AUD 12.50');
      expect(testCurrentOwingBalance.memberStatement, 'Taylor owes AUD 12.50');

      expect(testCurrentSettledBalance.position, BalancePosition.settled);
      expect(testCurrentSettledBalance.memberStatement, 'Taylor is settled up');
    });

    test('maps only integer minor units returned by the balance RPC', () {
      final balance = GroupBalance.fromMap(const {
        'group_member_id': 'guest-member',
        'display_name': 'Morgan',
        'role': 'member',
        'is_removed': true,
        'is_guest': true,
        'is_current_user': false,
        'net_balance_minor': '-200',
      }, currencyCode: 'AUD');

      expect(balance.netBalance.minorUnits, -200);
      expect(balance.isGuest, isTrue);
      expect(balance.isRemoved, isTrue);
      expect(
        () => GroupBalance.fromMap(const {
          'group_member_id': 'guest-member',
          'display_name': 'Morgan',
          'role': 'member',
          'net_balance_minor': 2.5,
        }, currencyCode: 'AUD'),
        throwsFormatException,
      );
    });

    test('orders the current member, active members, and removed members', () {
      final balances = GroupBalance.ordered(const [
        testRemovedGuestBalance,
        testGuestOwingBalance,
        testCurrentOwedBalance,
      ]);

      expect(balances.map((balance) => balance.groupMemberId), const [
        'owner-member',
        'guest-member',
        'removed-guest-member',
      ]);
    });
  });

  group('GroupBalanceSummary', () {
    test('summarises owed, owing, and settled current-user states', () {
      expect(
        GroupBalanceSummary.fromBalances(const [
          testCurrentOwedBalance,
        ]).statement,
        'You are owed AUD 30.00',
      );
      expect(
        GroupBalanceSummary.fromBalances(const [
          testCurrentOwingBalance,
        ]).statement,
        'You owe AUD 12.50',
      );
      expect(
        GroupBalanceSummary.fromBalances(const [
          testCurrentSettledBalance,
        ]).statement,
        'You are settled up',
      );
    });
  });

  test('maps database failures to safe user-facing messages', () {
    expect(
      BalancesErrorMapper.messageFor(
        Exception('Financial records are inconsistent'),
      ),
      "We couldn't calculate this group's balances right now.",
    );
    expect(
      BalancesErrorMapper.messageFor(Exception('network timeout')),
      'We could not reach OweLoop. Check your connection and try again.',
    );
  });
}
