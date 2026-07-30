import 'package:flutter/foundation.dart';

import '../data/balances_repository.dart';
import '../domain/balance_models.dart';
import '../errors/balances_error_mapper.dart';
import 'balances_state.dart';

class GroupBalancesController extends ChangeNotifier {
  GroupBalancesController({
    required this.groupId,
    required this.currencyCode,
    required this.repository,
  });

  final String groupId;
  final String currencyCode;
  final BalancesRepository repository;
  GroupBalancesState _state = const GroupBalancesState.loading();
  bool _isDisposed = false;
  int _sessionGeneration = 0;

  GroupBalancesState get state => _state;

  Future<void> load() async {
    final sessionGeneration = _sessionGeneration;
    if (_state.status == GroupBalancesStatus.loading &&
        _state.balances.isEmpty) {
      _setState(const GroupBalancesState.loading());
    } else {
      _setState(_state.copyWith(isRefreshing: true, clearErrorMessage: true));
    }

    try {
      final balances = await repository.loadGroupBalances(
        groupId: groupId,
        currencyCode: currencyCode,
      );
      if (sessionGeneration != _sessionGeneration) {
        return;
      }
      final orderedBalances = GroupBalance.ordered(balances);
      final summary = GroupBalanceSummary.fromBalances(orderedBalances);
      _setState(
        GroupBalancesState(
          status: GroupBalancesStatus.ready,
          balances: orderedBalances,
          summary: summary,
        ),
      );
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) {
        return;
      }
      if (BalancesErrorMapper.isUnavailable(error)) {
        _setState(
          const GroupBalancesState(status: GroupBalancesStatus.unavailable),
        );
        return;
      }
      _setState(
        GroupBalancesState(
          status: GroupBalancesStatus.error,
          balances: _state.balances,
          summary: _state.summary,
          errorMessage: BalancesErrorMapper.messageFor(error),
        ),
      );
    }
  }

  Future<void> refresh() => load();

  void clear() {
    _sessionGeneration += 1;
    _setState(const GroupBalancesState.loading());
  }

  void _setState(GroupBalancesState state) {
    if (_isDisposed) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
