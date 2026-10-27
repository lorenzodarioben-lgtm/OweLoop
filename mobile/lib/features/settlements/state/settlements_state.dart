import '../domain/settlement_models.dart';

enum SettlementHistoryStatus { loading, ready, unavailable, error }

class SettlementHistoryState {
  const SettlementHistoryState({
    required this.status,
    this.settlements = const [],
    this.errorMessage,
    this.isRefreshing = false,
    this.hasMore = false,
    this.voidingSettlementId,
  });

  const SettlementHistoryState.loading()
    : this(status: SettlementHistoryStatus.loading);

  final SettlementHistoryStatus status;
  final List<SettlementRecord> settlements;
  final String? errorMessage;
  final bool isRefreshing;
  final bool hasMore;
  final String? voidingSettlementId;

  SettlementHistoryState copyWith({
    SettlementHistoryStatus? status,
    List<SettlementRecord>? settlements,
    String? errorMessage,
    bool? isRefreshing,
    bool? hasMore,
    String? voidingSettlementId,
    bool clearErrorMessage = false,
    bool clearVoidingSettlementId = false,
  }) => SettlementHistoryState(
    status: status ?? this.status,
    settlements: settlements ?? this.settlements,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    hasMore: hasMore ?? this.hasMore,
    voidingSettlementId: clearVoidingSettlementId
        ? null
        : voidingSettlementId ?? this.voidingSettlementId,
  );
}

class SettlementCreationState {
  const SettlementCreationState({this.isSubmitting = false, this.errorMessage});

  final bool isSubmitting;
  final String? errorMessage;

  SettlementCreationState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) => SettlementCreationState(
    isSubmitting: isSubmitting ?? this.isSubmitting,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
  );
}
