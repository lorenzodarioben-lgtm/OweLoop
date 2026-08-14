import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/groups/state/group_data_refresh_coordinator.dart';

void main() {
  test('coalesces repeated group refreshes into one set of requests', () async {
    final groupCompleter = Completer<void>();
    final balanceCompleter = Completer<void>();
    final expenseCompleter = Completer<void>();
    final settlementCompleter = Completer<void>();
    var groupListCalls = 0;
    var groupCalls = 0;
    var balanceCalls = 0;
    var expenseCalls = 0;
    var settlementCalls = 0;
    final coordinator = GroupDataRefreshCoordinator(
      refreshGroups: () async {
        groupListCalls += 1;
      },
      refreshGroup: () {
        groupCalls += 1;
        return groupCompleter.future;
      },
      refreshBalances: () {
        balanceCalls += 1;
        return balanceCompleter.future;
      },
      refreshExpenses: () {
        expenseCalls += 1;
        return expenseCompleter.future;
      },
      refreshSettlements: () {
        settlementCalls += 1;
        return settlementCompleter.future;
      },
    );

    final firstRefresh = coordinator.refresh();
    final repeatedRefresh = coordinator.refresh();

    expect(groupListCalls, 1);
    expect(groupCalls, 1);
    expect(balanceCalls, 1);
    expect(expenseCalls, 1);
    expect(settlementCalls, 1);

    groupCompleter.complete();
    balanceCompleter.complete();
    expenseCompleter.complete();
    settlementCompleter.complete();
    await Future.wait([firstRefresh, repeatedRefresh]);

    await coordinator.refresh();
    expect(groupListCalls, 2);
    expect(groupCalls, 2);
    expect(balanceCalls, 2);
    expect(expenseCalls, 2);
    expect(settlementCalls, 2);
  });
}
