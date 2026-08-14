import '../domain/guest_claim_models.dart';

enum GuestClaimInboxStatus { loading, ready, error }

class GuestClaimInboxState {
  const GuestClaimInboxState({
    required this.status,
    this.claimRequests = const [],
    this.errorMessage,
    this.isRefreshing = false,
    this.pendingActionId,
  });

  const GuestClaimInboxState.loading()
    : this(status: GuestClaimInboxStatus.loading);

  final GuestClaimInboxStatus status;
  final List<GuestClaimRequest> claimRequests;
  final String? errorMessage;
  final bool isRefreshing;
  final String? pendingActionId;

  GuestClaimInboxState copyWith({
    GuestClaimInboxStatus? status,
    List<GuestClaimRequest>? claimRequests,
    String? errorMessage,
    bool? isRefreshing,
    String? pendingActionId,
    bool clearErrorMessage = false,
    bool clearPendingActionId = false,
  }) => GuestClaimInboxState(
    status: status ?? this.status,
    claimRequests: claimRequests ?? this.claimRequests,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    pendingActionId: clearPendingActionId
        ? null
        : pendingActionId ?? this.pendingActionId,
  );
}

enum GroupGuestClaimsStatus { loading, ready, error }

class GroupGuestClaimsState {
  const GroupGuestClaimsState({
    required this.status,
    this.claimRequests = const [],
    this.errorMessage,
    this.successMessage,
    this.isRefreshing = false,
    this.creatingGuestMemberId,
    this.revokingClaimRequestId,
  });

  const GroupGuestClaimsState.loading()
    : this(status: GroupGuestClaimsStatus.loading);

  final GroupGuestClaimsStatus status;
  final List<SentGuestClaimRequest> claimRequests;
  final String? errorMessage;
  final String? successMessage;
  final bool isRefreshing;
  final String? creatingGuestMemberId;
  final String? revokingClaimRequestId;

  bool get isBusy =>
      creatingGuestMemberId != null || revokingClaimRequestId != null;

  GroupGuestClaimsState copyWith({
    GroupGuestClaimsStatus? status,
    List<SentGuestClaimRequest>? claimRequests,
    String? errorMessage,
    String? successMessage,
    bool? isRefreshing,
    String? creatingGuestMemberId,
    String? revokingClaimRequestId,
    bool clearErrorMessage = false,
    bool clearSuccessMessage = false,
    bool clearCreatingGuestMemberId = false,
    bool clearRevokingClaimRequestId = false,
  }) => GroupGuestClaimsState(
    status: status ?? this.status,
    claimRequests: claimRequests ?? this.claimRequests,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    successMessage: clearSuccessMessage
        ? null
        : successMessage ?? this.successMessage,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    creatingGuestMemberId: clearCreatingGuestMemberId
        ? null
        : creatingGuestMemberId ?? this.creatingGuestMemberId,
    revokingClaimRequestId: clearRevokingClaimRequestId
        ? null
        : revokingClaimRequestId ?? this.revokingClaimRequestId,
  );
}
