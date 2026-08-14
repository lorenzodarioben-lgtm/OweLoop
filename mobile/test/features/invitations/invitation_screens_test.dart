import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/authentication/state/authentication_providers.dart';
import 'package:oweloop/features/groups/state/groups_providers.dart';
import 'package:oweloop/features/invitations/presentation/group_invitations_section.dart';
import 'package:oweloop/features/invitations/presentation/invitation_inbox_screen.dart';
import 'package:oweloop/features/invitations/state/invitations_providers.dart';

import '../../fakes/authentication_fakes.dart';
import '../../fakes/groups_fakes.dart';
import '../../fakes/invitations_fakes.dart';

void main() {
  Widget buildScreen(Widget child, FakeInvitationsRepository invitations) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(restoredUser: testUser),
        ),
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(currentProfile: completedTestProfile),
        ),
        groupsRepositoryProvider.overrideWithValue(FakeGroupsRepository()),
        invitationsRepositoryProvider.overrideWithValue(invitations),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('shows the recipient inbox and accepts an invitation', (
    tester,
  ) async {
    final repository = FakeInvitationsRepository()
      ..pendingInvitations = [testGroupInvitation];
    await tester.pumpWidget(
      buildScreen(const InvitationInboxScreen(), repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekend trip'), findsOneWidget);
    expect(find.textContaining('Invited by Taylor'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
    await tester.pumpAndSettle();

    expect(repository.acceptedInvitationId, testGroupInvitation.id);
    expect(find.text('No pending invitations'), findsOneWidget);
    expect(find.text('You joined Weekend trip.'), findsOneWidget);
  });

  testWidgets('creates a generic group invitation and exposes revoke control', (
    tester,
  ) async {
    final repository = FakeInvitationsRepository()
      ..groupInvitations = [testSentGroupInvitation];
    await tester.pumpWidget(
      buildScreen(
        const SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: GroupInvitationsSection(groupId: 'group-1'),
          ),
        ),
        repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('morgan@example.test'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('group-invitation-email-input')),
      'new-member@example.test',
    );
    await tester.tap(find.byKey(const Key('create-group-invitation-button')));
    await tester.pumpAndSettle();

    expect(
      repository.lastCreateInput?.normalizedEmail,
      'new-member@example.test',
    );
    expect(find.textContaining('eligible OweLoop account'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Revoke'), findsOneWidget);
  });
}
