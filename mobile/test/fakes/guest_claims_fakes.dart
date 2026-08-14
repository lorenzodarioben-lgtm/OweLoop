import 'package:oweloop/features/guest_claims/data/guest_claims_repository.dart';
import 'package:oweloop/features/guest_claims/domain/guest_claim_models.dart';

class FakeGuestClaimsRepository implements GuestClaimsRepository {
  List<GuestClaimRequest> pendingClaimRequests = [];
  List<SentGuestClaimRequest> groupClaimRequests = [];
  Object? loadPendingError;
  Object? loadGroupError;
  Object? createError;
  Object? acceptError;
  Object? declineError;
  Object? revokeError;
  String? lastCreateGroupId;
  String? lastGuestMemberId;
  GuestClaimInput? lastCreateInput;
  String? acceptedClaimRequestId;
  String? declinedClaimRequestId;
  String? revokedClaimRequestId;

  @override
  Future<List<GuestClaimRequest>> loadPendingClaimRequests() async {
    if (loadPendingError != null) throw loadPendingError!;
    return List<GuestClaimRequest>.from(pendingClaimRequests);
  }

  @override
  Future<List<SentGuestClaimRequest>> loadGroupClaimRequests(
    String groupId,
  ) async {
    if (loadGroupError != null) throw loadGroupError!;
    return List<SentGuestClaimRequest>.from(groupClaimRequests);
  }

  @override
  Future<void> createClaimRequest({
    required String groupId,
    required String guestMemberId,
    required GuestClaimInput input,
  }) async {
    lastCreateGroupId = groupId;
    lastGuestMemberId = guestMemberId;
    lastCreateInput = input;
    if (createError != null) throw createError!;
  }

  @override
  Future<void> acceptClaimRequest(String claimRequestId) async {
    acceptedClaimRequestId = claimRequestId;
    if (acceptError != null) throw acceptError!;
    pendingClaimRequests.removeWhere((request) => request.id == claimRequestId);
  }

  @override
  Future<void> declineClaimRequest(String claimRequestId) async {
    declinedClaimRequestId = claimRequestId;
    if (declineError != null) throw declineError!;
    pendingClaimRequests.removeWhere((request) => request.id == claimRequestId);
  }

  @override
  Future<void> revokeClaimRequest(String claimRequestId) async {
    revokedClaimRequestId = claimRequestId;
    if (revokeError != null) throw revokeError!;
    groupClaimRequests.removeWhere((request) => request.id == claimRequestId);
  }
}

final testGuestClaimRequest = GuestClaimRequest(
  id: 'claim-request-1',
  groupId: 'group-1',
  groupName: 'Weekend trip',
  currencyCode: 'AUD',
  guestMemberId: 'guest-member',
  guestDisplayName: 'Morgan',
  initiatedByDisplayName: 'Taylor',
  expiresAt: DateTime.utc(2026, 9, 1),
);

final testSentGuestClaimRequest = SentGuestClaimRequest(
  id: 'sent-claim-request-1',
  guestMemberId: 'guest-member',
  guestDisplayName: 'Morgan',
  recipientEmail: 'morgan@example.test',
  createdAt: DateTime.utc(2026, 8, 15),
  expiresAt: DateTime.utc(2026, 8, 29),
);
