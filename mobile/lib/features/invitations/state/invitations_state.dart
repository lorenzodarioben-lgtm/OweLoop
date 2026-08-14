import '../domain/invitation_models.dart';

enum InvitationInboxStatus { loading, ready, error }

class InvitationInboxState {
  const InvitationInboxState({
    required this.status,
    this.invitations = const [],
    this.errorMessage,
    this.isRefreshing = false,
    this.pendingActionId,
  });

  const InvitationInboxState.loading()
    : this(status: InvitationInboxStatus.loading);

  final InvitationInboxStatus status;
  final List<GroupInvitation> invitations;
  final String? errorMessage;
  final bool isRefreshing;
  final String? pendingActionId;

  InvitationInboxState copyWith({
    InvitationInboxStatus? status,
    List<GroupInvitation>? invitations,
    String? errorMessage,
    bool? isRefreshing,
    String? pendingActionId,
    bool clearErrorMessage = false,
    bool clearPendingActionId = false,
  }) => InvitationInboxState(
    status: status ?? this.status,
    invitations: invitations ?? this.invitations,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    pendingActionId: clearPendingActionId
        ? null
        : pendingActionId ?? this.pendingActionId,
  );
}

enum GroupInvitationsStatus { loading, ready, error }

class GroupInvitationsState {
  const GroupInvitationsState({
    required this.status,
    this.invitations = const [],
    this.errorMessage,
    this.successMessage,
    this.isRefreshing = false,
    this.isCreating = false,
    this.revokingInvitationId,
  });

  const GroupInvitationsState.loading()
    : this(status: GroupInvitationsStatus.loading);

  final GroupInvitationsStatus status;
  final List<SentGroupInvitation> invitations;
  final String? errorMessage;
  final String? successMessage;
  final bool isRefreshing;
  final bool isCreating;
  final String? revokingInvitationId;

  GroupInvitationsState copyWith({
    GroupInvitationsStatus? status,
    List<SentGroupInvitation>? invitations,
    String? errorMessage,
    String? successMessage,
    bool? isRefreshing,
    bool? isCreating,
    String? revokingInvitationId,
    bool clearErrorMessage = false,
    bool clearSuccessMessage = false,
    bool clearRevokingInvitationId = false,
  }) => GroupInvitationsState(
    status: status ?? this.status,
    invitations: invitations ?? this.invitations,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    successMessage: clearSuccessMessage
        ? null
        : successMessage ?? this.successMessage,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isCreating: isCreating ?? this.isCreating,
    revokingInvitationId: clearRevokingInvitationId
        ? null
        : revokingInvitationId ?? this.revokingInvitationId,
  );
}
