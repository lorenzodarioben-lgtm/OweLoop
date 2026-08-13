import '../domain/balance_models.dart';

enum GroupBalancesStatus { loading, ready, unavailable, error }

class GroupBalancesState {
  const GroupBalancesState({
    required this.status,
    this.balances = const [],
    this.summary,
    this.errorMessage,
    this.isRefreshing = false,
  });

  const GroupBalancesState.loading()
    : this(status: GroupBalancesStatus.loading);

  final GroupBalancesStatus status;
  final List<GroupBalance> balances;
  final GroupBalanceSummary? summary;
  final String? errorMessage;
  final bool isRefreshing;

  GroupBalancesState copyWith({
    GroupBalancesStatus? status,
    List<GroupBalance>? balances,
    GroupBalanceSummary? summary,
    String? errorMessage,
    bool? isRefreshing,
    bool clearSummary = false,
    bool clearErrorMessage = false,
  }) {
    return GroupBalancesState(
      status: status ?? this.status,
      balances: balances ?? this.balances,
      summary: clearSummary ? null : summary ?? this.summary,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
