import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../balances/state/balances_providers.dart';
import '../../expenses/state/expenses_providers.dart';
import '../../settlements/state/settlements_providers.dart';
import 'groups_providers.dart';

class GroupDataRefreshCoordinator {
  GroupDataRefreshCoordinator({
    required this.refreshGroups,
    required this.refreshGroup,
    required this.refreshBalances,
    required this.refreshExpenses,
    required this.refreshSettlements,
  });

  final Future<void> Function() refreshGroups;
  final Future<void> Function() refreshGroup;
  final Future<void> Function() refreshBalances;
  final Future<void> Function() refreshExpenses;
  final Future<void> Function() refreshSettlements;
  Future<void>? _activeRefresh;

  Future<void> refresh() {
    return _activeRefresh ??= _refresh().whenComplete(() {
      _activeRefresh = null;
    });
  }

  Future<void> _refresh() => Future.wait([
    refreshGroups(),
    refreshGroup(),
    refreshBalances(),
    refreshExpenses(),
    refreshSettlements(),
  ]);
}

final groupDataRefreshCoordinatorProvider =
    Provider.family<
      GroupDataRefreshCoordinator,
      ({String groupId, String currencyCode})
    >((ref, request) {
      return GroupDataRefreshCoordinator(
        refreshGroups: ref.read(groupsControllerProvider).refresh,
        refreshGroup: ref
            .read(groupDetailControllerProvider(request.groupId))
            .load,
        refreshBalances: ref
            .read(
              groupBalancesControllerProvider((
                groupId: request.groupId,
                currencyCode: request.currencyCode,
              )),
            )
            .refresh,
        refreshExpenses: ref
            .read(expenseHistoryControllerProvider(request.groupId))
            .refresh,
        refreshSettlements: ref
            .read(
              settlementHistoryControllerProvider((
                groupId: request.groupId,
                currencyCode: request.currencyCode,
              )),
            )
            .refresh,
      );
    });
