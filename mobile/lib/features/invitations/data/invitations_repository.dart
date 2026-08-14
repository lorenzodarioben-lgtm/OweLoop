import '../domain/invitation_models.dart';

abstract interface class InvitationsRepository {
  Future<List<GroupInvitation>> loadPendingInvitations();

  Future<List<SentGroupInvitation>> loadGroupInvitations(String groupId);

  Future<void> createInvitation({
    required String groupId,
    required GroupInvitationInput input,
  });

  Future<void> acceptInvitation(String invitationId);

  Future<void> declineInvitation(String invitationId);

  Future<void> revokeInvitation(String invitationId);
}
