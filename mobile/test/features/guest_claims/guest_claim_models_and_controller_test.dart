import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/guest_claims/domain/guest_claim_models.dart';
import 'package:oweloop/features/guest_claims/state/guest_claims_controller.dart';
import 'package:oweloop/features/guest_claims/state/guest_claims_state.dart';

import '../../fakes/guest_claims_fakes.dart';

void main() {
  test('maps guest claim RPC rows and normalizes email input', () {
    final request = GuestClaimRequest.fromInboxMap(<String, dynamic>{
      'claim_request_id': 'claim-request-1',
      'group_id': 'group-1',
      'group_name': 'Weekend trip',
      'currency_code': 'AUD',
      'guest_member_id': 'guest-member',
      'guest_display_name': 'Morgan',
      'initiated_by_display_name': 'Taylor',
      'expires_at': '2026-09-01T00:00:00Z',
    });
    const input = GuestClaimInput(email: ' Morgan@Example.Test ');

    expect(request.guestMemberId, 'guest-member');
    expect(request.initiatedByDisplayName, 'Taylor');
    expect(input.normalizedEmail, 'morgan@example.test');
  });

  test('accepts and clears a guest claim inbox on session cleanup', () async {
    final repository = FakeGuestClaimsRepository()
      ..pendingClaimRequests = [testGuestClaimRequest];
    final controller = GuestClaimInboxController(repository);

    await controller.load();
    expect(controller.state.status, GuestClaimInboxStatus.ready);
    expect(await controller.accept(testGuestClaimRequest.id), isTrue);
    expect(repository.acceptedClaimRequestId, testGuestClaimRequest.id);
    expect(controller.state.claimRequests, isEmpty);

    controller.clear();
    expect(controller.state.status, GuestClaimInboxStatus.loading);
  });

  test('creates a generic claim request and supports revocation', () async {
    final repository = FakeGuestClaimsRepository()
      ..groupClaimRequests = [testSentGuestClaimRequest];
    final controller = GroupGuestClaimsController(
      groupId: 'group-1',
      repository: repository,
    );
    await controller.load();

    expect(
      await controller.create(
        guestMemberId: 'guest-member',
        input: const GuestClaimInput(email: 'Morgan@Example.Test'),
      ),
      isTrue,
    );
    expect(repository.lastGuestMemberId, 'guest-member');
    expect(repository.lastCreateInput?.normalizedEmail, 'morgan@example.test');
    expect(
      controller.state.successMessage,
      contains('eligible OweLoop account'),
    );

    expect(await controller.revoke(testSentGuestClaimRequest.id), isTrue);
    expect(repository.revokedClaimRequestId, testSentGuestClaimRequest.id);
    expect(controller.state.claimRequests, isEmpty);
  });

  test('shows a safe error without exposing guest claim state', () async {
    final repository = FakeGuestClaimsRepository()
      ..acceptError = const GuestClaimRepositoryException(
        'Guest claim request is unavailable',
      )
      ..pendingClaimRequests = [testGuestClaimRequest];
    final controller = GuestClaimInboxController(repository);
    await controller.load();

    expect(await controller.accept(testGuestClaimRequest.id), isFalse);
    expect(
      controller.state.errorMessage,
      'This guest claim request is no longer available.',
    );
  });
}
