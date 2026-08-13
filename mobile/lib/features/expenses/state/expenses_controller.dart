import 'package:flutter/foundation.dart';

import '../data/expenses_repository.dart';
import '../domain/expense_models.dart';
import '../errors/expenses_error_mapper.dart';
import 'expenses_state.dart';

class ExpenseHistoryController extends ChangeNotifier {
  ExpenseHistoryController({required this.groupId, required this.repository});

  final String groupId;
  final ExpensesRepository repository;
  ExpenseHistoryState _state = const ExpenseHistoryState.loading();
  bool _isDisposed = false;
  int _sessionGeneration = 0;

  ExpenseHistoryState get state => _state;

  Future<void> load() async {
    final sessionGeneration = _sessionGeneration;
    if (_state.status == ExpenseHistoryStatus.loading &&
        _state.expenses.isEmpty) {
      _setState(const ExpenseHistoryState.loading());
    } else {
      _setState(_state.copyWith(isRefreshing: true, clearErrorMessage: true));
    }

    try {
      final expenses = await repository.loadPostedExpenses(groupId);
      if (sessionGeneration != _sessionGeneration) {
        return;
      }
      _setState(
        ExpenseHistoryState(
          status: ExpenseHistoryStatus.ready,
          expenses: expenses,
        ),
      );
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) {
        return;
      }
      _setState(
        ExpenseHistoryState(
          status: ExpenseHistoryStatus.error,
          expenses: _state.expenses,
          errorMessage: ExpensesErrorMapper.messageFor(error),
        ),
      );
    }
  }

  Future<void> refresh() => load();

  void clear() {
    _sessionGeneration += 1;
    _setState(const ExpenseHistoryState.loading());
  }

  void _setState(ExpenseHistoryState state) {
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

class ExpenseCreationController extends ChangeNotifier {
  ExpenseCreationController(this._repository);

  final ExpensesRepository _repository;
  ExpenseCreationState _state = const ExpenseCreationState();
  bool _isDisposed = false;
  int _sessionGeneration = 0;

  ExpenseCreationState get state => _state;

  Future<ExpenseRecord?> create(ExpenseCreationInput input) async {
    if (_state.isSubmitting) {
      return null;
    }

    final sessionGeneration = _sessionGeneration;
    _setState(_state.copyWith(isSubmitting: true, clearErrorMessage: true));
    try {
      final expense = await _repository.createExpense(input);
      if (sessionGeneration != _sessionGeneration) {
        return null;
      }
      _setState(const ExpenseCreationState());
      return expense;
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) {
        return null;
      }
      _setState(
        ExpenseCreationState(
          errorMessage: ExpensesErrorMapper.messageFor(error),
        ),
      );
      return null;
    }
  }

  void clear() {
    _sessionGeneration += 1;
    _setState(const ExpenseCreationState());
  }

  void _setState(ExpenseCreationState state) {
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

class ExpenseDetailController extends ChangeNotifier {
  ExpenseDetailController({
    required this.groupId,
    required this.expenseId,
    required this.repository,
  });

  final String groupId;
  final String expenseId;
  final ExpensesRepository repository;
  ExpenseDetailState _state = const ExpenseDetailState.loading();
  bool _isDisposed = false;
  int _sessionGeneration = 0;

  ExpenseDetailState get state => _state;

  Future<void> load() async {
    final sessionGeneration = _sessionGeneration;
    _setState(const ExpenseDetailState.loading());
    try {
      final expense = await repository.loadAccessibleExpense(expenseId);
      if (sessionGeneration != _sessionGeneration) {
        return;
      }
      if (expense == null || expense.groupId != groupId) {
        _setState(
          const ExpenseDetailState(status: ExpenseDetailStatus.unavailable),
        );
        return;
      }
      _setState(
        ExpenseDetailState(status: ExpenseDetailStatus.ready, expense: expense),
      );
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) {
        return;
      }
      _setState(
        ExpenseDetailState(
          status: ExpenseDetailStatus.error,
          errorMessage: ExpensesErrorMapper.messageFor(error),
        ),
      );
    }
  }

  void clear() {
    _sessionGeneration += 1;
    _setState(const ExpenseDetailState.loading());
  }

  void _setState(ExpenseDetailState state) {
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
