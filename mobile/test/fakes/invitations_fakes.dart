import 'package:oweloop/features/invitations/data/invitations_repository.dart';
import 'package:oweloop/features/invitations/domain/invitation_models.dart';

class FakeInvitationsRepository implements InvitationsRepository {
  List<GroupInvitation> pendingInvitations = [];
  List<SentGroupInvitation> groupInvitations = [];
  Object? loadPendingError;
  Object? loadGroupError;
  Object? createError;
  Object? acceptError;
  Object? declineError;
  Object? revokeError;
  int loadPendingCalls = 0;
  int loadGroupCalls = 0;
  GroupInvitationInput? lastCreateInput;
  String? lastCreateGroupId;
  String? acceptedInvitationId;
  String? declinedInvitationId;
  String? revokedInvitationId;

  @override
  Future<List<GroupInvitation>> loadPendingInvitations() async {
    loadPendingCalls += 1;
    if (loadPendingError != null) throw loadPendingError!;
    return List<GroupInvitation>.from(pendingInvitations);
  }

  @override
  Future<List<SentGroupInvitation>> loadGroupInvitations(String groupId) async {
    loadGroupCalls += 1;
    if (loadGroupError != null) throw loadGroupError!;
    return List<SentGroupInvitation>.from(groupInvitations);
  }

  @override
  Future<void> createInvitation({
    required String groupId,
    required GroupInvitationInput input,
  }) async {
    lastCreateGroupId = groupId;
    lastCreateInput = input;
    if (createError != null) throw createError!;
  }

  @override
  Future<void> acceptInvitation(String invitationId) async {
    acceptedInvitationId = invitationId;
    if (acceptError != null) throw acceptError!;
    pendingInvitations.removeWhere(
      (invitation) => invitation.id == invitationId,
    );
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    declinedInvitationId = invitationId;
    if (declineError != null) throw declineError!;
    pendingInvitations.removeWhere(
      (invitation) => invitation.id == invitationId,
    );
  }

  @override
  Future<void> revokeInvitation(String invitationId) async {
    revokedInvitationId = invitationId;
    if (revokeError != null) throw revokeError!;
    groupInvitations.removeWhere((invitation) => invitation.id == invitationId);
  }
}

final testGroupInvitation = GroupInvitation(
  id: 'invitation-1',
  groupId: 'group-1',
  groupName: 'Weekend trip',
  currencyCode: 'AUD',
  inviterDisplayName: 'Taylor',
  expiresAt: DateTime.utc(2026, 9, 1),
);

final testSentGroupInvitation = SentGroupInvitation(
  id: 'sent-invitation-1',
  recipientEmail: 'morgan@example.test',
  createdAt: DateTime.utc(2026, 8, 15),
  expiresAt: DateTime.utc(2026, 8, 29),
);
