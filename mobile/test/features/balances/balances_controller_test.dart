import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/balances/domain/balance_models.dart';
import 'package:oweloop/features/balances/errors/balances_error_mapper.dart';
import 'package:oweloop/features/balances/state/balances_controller.dart';
import 'package:oweloop/features/balances/state/balances_state.dart';

import '../../fakes/balances_fakes.dart';

void main() {
  GroupBalancesController controllerFor(FakeBalancesRepository repository) {
    return GroupBalancesController(
      groupId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      currencyCode: 'AUD',
      repository: repository,
    );
  }

  test(
    'loads a zero-expense group and orders the result deterministically',
    () async {
      final repository = FakeBalancesRepository(
        balances: const [testGuestOwingBalance, testCurrentSettledBalance],
      );
      final controller = controllerFor(repository);

      await controller.load();

      expect(controller.state.status, GroupBalancesStatus.ready);
      expect(controller.state.summary?.statement, 'You are settled up');
      expect(
        controller.state.balances.map((balance) => balance.groupMemberId),
        const ['owner-member', 'guest-member'],
      );
      expect(repository.lastGroupId, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
      expect(repository.lastCurrencyCode, 'AUD');
    },
  );

  test('shows a safe error and supports retry', () async {
    final repository = FakeBalancesRepository()
      ..loadBalancesError = Exception('network timeout');
    final controller = controllerFor(repository);

    await controller.load();

    expect(controller.state.status, GroupBalancesStatus.error);
    expect(
      controller.state.errorMessage,
      'We could not reach OweLoop. Check your connection and try again.',
    );

    repository
      ..loadBalancesError = null
      ..balances = const [testCurrentOwedBalance, testGuestOwingBalance];
    await controller.refresh();

    expect(controller.state.status, GroupBalancesStatus.ready);
    expect(controller.state.summary?.statement, 'You are owed AUD 30.00');
    expect(repository.loadBalancesCalls, 2);
  });

  test('treats an unavailable group as a distinct safe state', () async {
    final controller = controllerFor(
      FakeBalancesRepository()
        ..loadBalancesError = Exception('Group is unavailable'),
    );

    await controller.load();

    expect(controller.state.status, GroupBalancesStatus.unavailable);
    expect(controller.state.errorMessage, isNull);
  });

  test('ignores an in-flight response after sign-out cleanup', () async {
    final completer = Completer<List<GroupBalance>>();
    final repository = FakeBalancesRepository()
      ..loadBalancesHandler = () async {
        return completer.future;
      };
    final controller = controllerFor(repository);

    final pendingLoad = controller.load();
    controller.clear();
    completer.complete(const [testCurrentOwedBalance, testGuestOwingBalance]);
    await pendingLoad;

    expect(controller.state.status, GroupBalancesStatus.loading);
    expect(controller.state.balances, isEmpty);
  });

  test('does not expose inconsistent-record details to the UI', () {
    expect(
      BalancesErrorMapper.messageFor(
        Exception('Financial records are inconsistent'),
      ),
      "We couldn't calculate this group's balances right now.",
    );
  });
}
