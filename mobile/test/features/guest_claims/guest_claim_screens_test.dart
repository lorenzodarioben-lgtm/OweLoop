import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/authentication/state/authentication_providers.dart';
import 'package:oweloop/features/balances/state/balances_providers.dart';
import 'package:oweloop/features/expenses/state/expenses_providers.dart';
import 'package:oweloop/features/guest_claims/presentation/guest_claim_dialog.dart';
import 'package:oweloop/features/guest_claims/presentation/guest_claim_inbox_screen.dart';
import 'package:oweloop/features/guest_claims/state/guest_claims_providers.dart';
import 'package:oweloop/features/groups/domain/group_models.dart';
import 'package:oweloop/features/groups/state/groups_providers.dart';
import 'package:oweloop/features/settlements/state/settlements_providers.dart';

import '../../fakes/authentication_fakes.dart';
import '../../fakes/balances_fakes.dart';
import '../../fakes/expenses_fakes.dart';
import '../../fakes/guest_claims_fakes.dart';
import '../../fakes/groups_fakes.dart';
import '../../fakes/settlements_fakes.dart';

void main() {
  Widget buildScreen(Widget child, FakeGuestClaimsRepository claims) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(restoredUser: testUser),
        ),
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(currentProfile: completedTestProfile),
        ),
        groupsRepositoryProvider.overrideWithValue(FakeGroupsRepository()),
        balancesRepositoryProvider.overrideWithValue(FakeBalancesRepository()),
        expensesRepositoryProvider.overrideWithValue(FakeExpensesRepository()),
        settlementsRepositoryProvider.overrideWithValue(
          FakeSettlementsRepository(),
        ),
        guestClaimsRepositoryProvider.overrideWithValue(claims),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('shows and accepts a protected guest claim request', (
    tester,
  ) async {
    final repository = FakeGuestClaimsRepository()
      ..pendingClaimRequests = [testGuestClaimRequest];
    await tester.pumpWidget(
      buildScreen(const GuestClaimInboxScreen(), repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('Morgan'), findsOneWidget);
    expect(find.textContaining('Requested by Taylor'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Accept claim'));
    await tester.pumpAndSettle();

    expect(repository.acceptedClaimRequestId, testGuestClaimRequest.id);
    expect(find.text('No pending guest claim requests'), findsOneWidget);
    expect(find.text('Morgan is now linked to your account.'), findsOneWidget);
  });

  testWidgets('submits a two-party guest claim request from the guest action', (
    tester,
  ) async {
    final repository = FakeGuestClaimsRepository();
    const guest = GroupMember(
      id: 'guest-member',
      displayName: 'Morgan',
      role: GroupRole.member,
      userId: null,
    );
    await tester.pumpWidget(
      buildScreen(
        Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    const GuestClaimDialog(groupId: 'group-1', guest: guest),
              ),
              child: const Text('Request account claim'),
            ),
          ),
        ),
        repository,
      ),
    );
    await tester.tap(find.text('Request account claim'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('guest-claim-email-input')),
      'morgan@example.test',
    );
    await tester.tap(find.byKey(const Key('create-guest-claim-button')));
    await tester.pumpAndSettle();

    expect(repository.lastCreateGroupId, 'group-1');
    expect(repository.lastGuestMemberId, guest.id);
    expect(repository.lastCreateInput?.normalizedEmail, 'morgan@example.test');
    expect(find.byType(AlertDialog), findsNothing);
  });
}
