import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/invitation_models.dart';
import 'invitations_repository.dart';

class SupabaseInvitationsRepository implements InvitationsRepository {
  SupabaseInvitationsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<GroupInvitation>> loadPendingInvitations() async {
    final rows = await _client.rpc('get_pending_group_invitations');
    return (rows as List)
        .map(
          (row) => GroupInvitation.fromInboxMap(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  @override
  Future<List<SentGroupInvitation>> loadGroupInvitations(String groupId) async {
    final rows = await _client.rpc(
      'get_group_invitations',
      params: <String, dynamic>{'p_group_id': groupId},
    );
    return (rows as List)
        .map(
          (row) => SentGroupInvitation.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  @override
  Future<void> createInvitation({
    required String groupId,
    required GroupInvitationInput input,
  }) async {
    await _client.rpc(
      'create_group_invitation',
      params: <String, dynamic>{
        'p_group_id': groupId,
        'p_recipient_email': input.normalizedEmail,
      },
    );
  }

  @override
  Future<void> acceptInvitation(String invitationId) => _client.rpc(
    'accept_group_invitation',
    params: <String, dynamic>{'p_invitation_id': invitationId},
  );

  @override
  Future<void> declineInvitation(String invitationId) => _client.rpc(
    'decline_group_invitation',
    params: <String, dynamic>{'p_invitation_id': invitationId},
  );

  @override
  Future<void> revokeInvitation(String invitationId) => _client.rpc(
    'revoke_group_invitation',
    params: <String, dynamic>{'p_invitation_id': invitationId},
  );
}
