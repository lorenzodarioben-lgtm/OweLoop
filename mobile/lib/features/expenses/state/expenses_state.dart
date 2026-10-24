import '../domain/expense_models.dart';

enum ExpenseHistoryStatus { loading, ready, error }

class ExpenseHistoryState {
  const ExpenseHistoryState({
    required this.status,
    this.expenses = const [],
    this.errorMessage,
    this.isRefreshing = false,
    this.hasMore = false,
  });

  const ExpenseHistoryState.loading()
    : this(status: ExpenseHistoryStatus.loading);

  final ExpenseHistoryStatus status;
  final List<ExpenseRecord> expenses;
  final String? errorMessage;
  final bool isRefreshing;
  final bool hasMore;

  ExpenseHistoryState copyWith({
    ExpenseHistoryStatus? status,
    List<ExpenseRecord>? expenses,
    String? errorMessage,
    bool? isRefreshing,
    bool? hasMore,
    bool clearErrorMessage = false,
  }) {
    return ExpenseHistoryState(
      status: status ?? this.status,
      expenses: expenses ?? this.expenses,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class ExpenseCreationState {
  const ExpenseCreationState({this.isSubmitting = false, this.errorMessage});

  final bool isSubmitting;
  final String? errorMessage;

  ExpenseCreationState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ExpenseCreationState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}

enum ExpenseDetailStatus { loading, ready, unavailable, error }

class ExpenseDetailState {
  const ExpenseDetailState({
    required this.status,
    this.expense,
    this.errorMessage,
    this.isVoiding = false,
  });

  const ExpenseDetailState.loading()
    : this(status: ExpenseDetailStatus.loading);

  final ExpenseDetailStatus status;
  final ExpenseRecord? expense;
  final String? errorMessage;
  final bool isVoiding;

  ExpenseDetailState copyWith({
    ExpenseDetailStatus? status,
    ExpenseRecord? expense,
    String? errorMessage,
    bool? isVoiding,
    bool clearErrorMessage = false,
  }) => ExpenseDetailState(
    status: status ?? this.status,
    expense: expense ?? this.expense,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    isVoiding: isVoiding ?? this.isVoiding,
  );
}
