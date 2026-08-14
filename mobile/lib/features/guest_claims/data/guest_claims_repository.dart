import '../domain/guest_claim_models.dart';

abstract interface class GuestClaimsRepository {
  Future<List<GuestClaimRequest>> loadPendingClaimRequests();

  Future<List<SentGuestClaimRequest>> loadGroupClaimRequests(String groupId);

  Future<void> createClaimRequest({
    required String groupId,
    required String guestMemberId,
    required GuestClaimInput input,
  });

  Future<void> acceptClaimRequest(String claimRequestId);

  Future<void> declineClaimRequest(String claimRequestId);

  Future<void> revokeClaimRequest(String claimRequestId);
}
