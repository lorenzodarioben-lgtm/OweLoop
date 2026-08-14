import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/guest_claim_models.dart';
import 'guest_claims_repository.dart';

class SupabaseGuestClaimsRepository implements GuestClaimsRepository {
  SupabaseGuestClaimsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<GuestClaimRequest>> loadPendingClaimRequests() async {
    final rows = await _client.rpc('get_pending_guest_claim_requests');
    return (rows as List)
        .map(
          (row) =>
              GuestClaimRequest.fromInboxMap(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  @override
  Future<List<SentGuestClaimRequest>> loadGroupClaimRequests(
    String groupId,
  ) async {
    final rows = await _client.rpc(
      'get_group_guest_claim_requests',
      params: <String, dynamic>{'p_group_id': groupId},
    );
    return (rows as List)
        .map(
          (row) =>
              SentGuestClaimRequest.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  @override
  Future<void> createClaimRequest({
    required String groupId,
    required String guestMemberId,
    required GuestClaimInput input,
  }) => _client.rpc(
    'create_guest_claim_request',
    params: <String, dynamic>{
      'p_group_id': groupId,
      'p_guest_member_id': guestMemberId,
      'p_recipient_email': input.normalizedEmail,
    },
  );

  @override
  Future<void> acceptClaimRequest(String claimRequestId) => _client.rpc(
    'accept_guest_claim_request',
    params: <String, dynamic>{'p_claim_request_id': claimRequestId},
  );

  @override
  Future<void> declineClaimRequest(String claimRequestId) => _client.rpc(
    'decline_guest_claim_request',
    params: <String, dynamic>{'p_claim_request_id': claimRequestId},
  );

  @override
  Future<void> revokeClaimRequest(String claimRequestId) => _client.rpc(
    'revoke_guest_claim_request',
    params: <String, dynamic>{'p_claim_request_id': claimRequestId},
  );
}
