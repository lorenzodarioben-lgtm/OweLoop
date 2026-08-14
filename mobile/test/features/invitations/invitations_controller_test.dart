import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/invitations/domain/invitation_models.dart';
import 'package:oweloop/features/invitations/state/invitations_controller.dart';
import 'package:oweloop/features/invitations/state/invitations_state.dart';

import '../../fakes/invitations_fakes.dart';

void main() {
  test('loads, accepts, and clears a private invitation inbox', () async {
    final repository = FakeInvitationsRepository()
      ..pendingInvitations = [testGroupInvitation];
    final controller = InvitationInboxController(repository);

    await controller.load();
    expect(controller.state.status, InvitationInboxStatus.ready);
    expect(controller.state.invitations, [testGroupInvitation]);

    expect(await controller.accept(testGroupInvitation.id), isTrue);
    expect(repository.acceptedInvitationId, testGroupInvitation.id);
    expect(controller.state.invitations, isEmpty);

    controller.clear();
    expect(controller.state.status, InvitationInboxStatus.loading);
    expect(controller.state.invitations, isEmpty);
  });

  test('keeps the inbox visible with a safe action error', () async {
    final repository = FakeInvitationsRepository()
      ..pendingInvitations = [testGroupInvitation]
      ..declineError = const InvitationRepositoryException(
        'Invitation is unavailable',
      );
    final controller = InvitationInboxController(repository);
    await controller.load();

    expect(await controller.decline(testGroupInvitation.id), isFalse);
    expect(controller.state.invitations, [testGroupInvitation]);
    expect(
      controller.state.errorMessage,
      'This invitation is no longer available.',
    );
  });

  test('creates generic feedback and revokes a group invitation', () async {
    final repository = FakeInvitationsRepository()
      ..groupInvitations = [testSentGroupInvitation];
    final controller = GroupInvitationsController(
      groupId: 'group-1',
      repository: repository,
    );
    await controller.load();

    expect(
      await controller.create(
        const GroupInvitationInput(email: 'Morgan@Example.Test'),
      ),
      isTrue,
    );
    expect(repository.lastCreateGroupId, 'group-1');
    expect(repository.lastCreateInput?.normalizedEmail, 'morgan@example.test');
    expect(
      controller.state.successMessage,
      contains('eligible OweLoop account'),
    );

    expect(await controller.revoke(testSentGroupInvitation.id), isTrue);
    expect(repository.revokedInvitationId, testSentGroupInvitation.id);
    expect(controller.state.invitations, isEmpty);
  });

  test('maps group invitation errors without exposing account state', () async {
    final repository = FakeInvitationsRepository()
      ..createError = const InvitationRepositoryException('network timeout');
    final controller = GroupInvitationsController(
      groupId: 'group-1',
      repository: repository,
    );
    await controller.load();

    expect(
      await controller.create(
        const GroupInvitationInput(email: 'unknown@example.test'),
      ),
      isFalse,
    );
    expect(
      controller.state.errorMessage,
      'We could not reach OweLoop. Check your connection and try again.',
    );
  });
}
