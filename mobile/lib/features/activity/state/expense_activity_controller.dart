import 'package:flutter/foundation.dart';

import '../../expenses/errors/expenses_error_mapper.dart';
import '../data/expense_activity_repository.dart';
import '../domain/expense_activity_models.dart';

enum ExpenseActivityStatus { loading, ready, unavailable, error }

class ExpenseActivityState {
  const ExpenseActivityState({
    required this.status,
    this.events = const [],
    this.errorMessage,
  });

  const ExpenseActivityState.loading()
    : this(status: ExpenseActivityStatus.loading);

  final ExpenseActivityStatus status;
  final List<ExpenseActivityEvent> events;
  final String? errorMessage;
}

class ExpenseActivityController extends ChangeNotifier {
  ExpenseActivityController({
    required this.expenseId,
    required this.currencyCode,
    required this.repository,
  });

  final String expenseId;
  final String currencyCode;
  final ExpenseActivityRepository repository;
  ExpenseActivityState _state = const ExpenseActivityState.loading();
  int _sessionGeneration = 0;
  bool _isDisposed = false;

  ExpenseActivityState get state => _state;

  Future<void> load() async {
    final generation = _sessionGeneration;
    _setState(const ExpenseActivityState.loading());
    try {
      final events = await repository.loadExpenseActivity(
        expenseId: expenseId,
        currencyCode: currencyCode,
      );
      if (generation != _sessionGeneration) return;
      _setState(
        ExpenseActivityState(
          status: ExpenseActivityStatus.ready,
          events: events,
        ),
      );
    } catch (error) {
      if (generation != _sessionGeneration) return;
      final message = ExpensesErrorMapper.messageFor(error);
      _setState(
        ExpenseActivityState(
          status: message == 'This expense is unavailable.'
              ? ExpenseActivityStatus.unavailable
              : ExpenseActivityStatus.error,
          errorMessage: message,
        ),
      );
    }
  }

  void clear() {
    _sessionGeneration += 1;
    _setState(const ExpenseActivityState.loading());
  }

  void _setState(ExpenseActivityState state) {
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
