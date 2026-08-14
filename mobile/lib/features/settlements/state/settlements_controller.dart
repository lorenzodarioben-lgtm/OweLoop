import 'package:flutter/foundation.dart';

import '../data/settlements_repository.dart';
import '../domain/settlement_models.dart';
import '../errors/settlements_error_mapper.dart';
import 'settlements_state.dart';

class SettlementHistoryController extends ChangeNotifier {
  SettlementHistoryController({
    required this.groupId,
    required this.currencyCode,
    required this.repository,
  });

  final String groupId;
  final String currencyCode;
  final SettlementsRepository repository;
  SettlementHistoryState _state = const SettlementHistoryState.loading();
  bool _isDisposed = false;
  int _sessionGeneration = 0;

  SettlementHistoryState get state => _state;

  Future<void> load() async {
    final sessionGeneration = _sessionGeneration;
    if (_state.status == SettlementHistoryStatus.loading &&
        _state.settlements.isEmpty) {
      _setState(const SettlementHistoryState.loading());
    } else {
      _setState(_state.copyWith(isRefreshing: true, clearErrorMessage: true));
    }
    try {
      final settlements = await repository.loadGroupSettlements(
        groupId: groupId,
        currencyCode: currencyCode,
      );
      if (sessionGeneration != _sessionGeneration) return;
      _setState(
        SettlementHistoryState(
          status: SettlementHistoryStatus.ready,
          settlements: settlements,
        ),
      );
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return;
      _setState(
        SettlementHistoryState(
          status: SettlementHistoryStatus.error,
          settlements: _state.settlements,
          errorMessage: SettlementsErrorMapper.messageFor(error),
        ),
      );
    }
  }

  Future<void> refresh() => load();

  Future<bool> voidSettlement(String settlementId) async {
    if (_state.voidingSettlementId != null) return false;
    _setState(
      _state.copyWith(
        voidingSettlementId: settlementId,
        clearErrorMessage: true,
      ),
    );
    try {
      await repository.voidSettlement(
        settlementId: settlementId,
        groupId: groupId,
        currencyCode: currencyCode,
      );
      await load();
      return true;
    } catch (error) {
      _setState(
        _state.copyWith(
          clearVoidingSettlementId: true,
          errorMessage: SettlementsErrorMapper.messageFor(error),
        ),
      );
      return false;
    }
  }

  void clear() {
    _sessionGeneration += 1;
    _setState(const SettlementHistoryState.loading());
  }

  void _setState(SettlementHistoryState state) {
    if (_isDisposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

class SettlementCreationController extends ChangeNotifier {
  SettlementCreationController(this._repository);

  final SettlementsRepository _repository;
  SettlementCreationState _state = const SettlementCreationState();
  bool _isDisposed = false;
  int _sessionGeneration = 0;

  SettlementCreationState get state => _state;

  Future<SettlementRecord?> record(SettlementCreationInput input) async {
    if (_state.isSubmitting) return null;
    final sessionGeneration = _sessionGeneration;
    _setState(_state.copyWith(isSubmitting: true, clearErrorMessage: true));
    try {
      final settlement = await _repository.recordSettlement(input);
      if (sessionGeneration != _sessionGeneration) return null;
      _setState(const SettlementCreationState());
      return settlement;
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return null;
      _setState(
        SettlementCreationState(
          errorMessage: SettlementsErrorMapper.messageFor(error),
        ),
      );
      return null;
    }
  }

  void clear() {
    _sessionGeneration += 1;
    _setState(const SettlementCreationState());
  }

  void _setState(SettlementCreationState state) {
    if (_isDisposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
