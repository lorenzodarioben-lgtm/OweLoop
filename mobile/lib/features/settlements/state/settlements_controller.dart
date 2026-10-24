import 'package:flutter/foundation.dart';
import '../../../core/operations/history_page.dart';

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
  HistoryCursor? _next;
  SettlementHistoryFilter _filter = const SettlementHistoryFilter();
  Future<void> filter(SettlementHistoryFilter filter) async {
    _filter = filter;
    _next = null;
    _setState(const SettlementHistoryState.loading());
    await load();
  }

  SettlementHistoryState get state => _state;

  Future<void> load() async {
    final sessionGeneration = ++_sessionGeneration;
    if (_state.status == SettlementHistoryStatus.loading &&
        _state.settlements.isEmpty) {
      _setState(const SettlementHistoryState.loading());
    } else {
      _setState(_state.copyWith(isRefreshing: true, clearErrorMessage: true));
    }
    try {
      final source = repository;
      final page = source is PagedSettlementsRepository
          ? await source.loadSettlementPage(
              groupId: groupId,
              currencyCode: currencyCode,
              filter: _filter,
            )
          : HistoryPage(
              items: await source.loadGroupSettlements(
                groupId: groupId,
                currencyCode: currencyCode,
              ),
            );
      final settlements = page.items;
      if (sessionGeneration != _sessionGeneration) return;
      _setState(
        SettlementHistoryState(
          status: SettlementHistoryStatus.ready,
          settlements: settlements,
          hasMore: page.next != null,
        ),
      );
      _next = page.next;
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

  Future<void> loadMore() async {
    final source = repository;
    if (_next == null ||
        _state.isRefreshing ||
        source is! PagedSettlementsRepository) {
      return;
    }
    final generation = _sessionGeneration;
    _setState(_state.copyWith(isRefreshing: true, clearErrorMessage: true));
    try {
      final page = await source.loadSettlementPage(
        groupId: groupId,
        currencyCode: currencyCode,
        before: _next,
        filter: _filter,
      );
      if (generation != _sessionGeneration) return;
      final ids = _state.settlements.map((entry) => entry.id).toSet();
      _next = page.next;
      _setState(
        _state.copyWith(
          settlements: [
            ..._state.settlements,
            ...page.items.where((entry) => ids.add(entry.id)),
          ],
          hasMore: _next != null,
          isRefreshing: false,
        ),
      );
    } catch (error) {
      if (generation == _sessionGeneration) {
        _setState(
          _state.copyWith(
            isRefreshing: false,
            errorMessage: SettlementsErrorMapper.messageFor(error),
          ),
        );
      }
    }
  }

  Future<bool> voidSettlement(String settlementId) async {
    if (_state.voidingSettlementId != null) return false;
    final generation = _sessionGeneration;
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
      if (generation != _sessionGeneration) return false;
      await load();
      return true;
    } catch (error) {
      if (generation != _sessionGeneration) return false;
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
    _next = null;
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
