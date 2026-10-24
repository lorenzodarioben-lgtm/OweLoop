import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/app/app_bootstrap.dart';
import 'package:oweloop/features/authentication/state/authentication_providers.dart';
import 'package:oweloop/features/activity/state/expense_activity_providers.dart';
import 'package:oweloop/features/balances/domain/balance_models.dart';
import 'package:oweloop/features/balances/state/balances_providers.dart';
import 'package:oweloop/features/expenses/domain/exact_money.dart';
import 'package:oweloop/features/expenses/state/expenses_providers.dart';
import 'package:oweloop/features/groups/domain/group_models.dart';
import 'package:oweloop/features/groups/presentation/group_feedback.dart';
import 'package:oweloop/features/groups/state/groups_providers.dart';
import 'package:oweloop/features/settlements/state/settlements_providers.dart';
import 'package:oweloop/features/invitations/state/invitations_providers.dart';
import 'package:oweloop/features/guest_claims/state/guest_claims_providers.dart';
import '../../fakes/invitations_fakes.dart';
import '../../fakes/guest_claims_fakes.dart';

import '../../fakes/authentication_fakes.dart';
import '../../fakes/activity_fakes.dart';
import '../../fakes/balances_fakes.dart';
import '../../fakes/expenses_fakes.dart';
import '../../fakes/groups_fakes.dart';
import '../../fakes/settlements_fakes.dart';

void main() {
  Widget buildApp(
    FakeGroupsRepository groupsRepository, {
    FakeExpensesRepository? expensesRepository,
    FakeBalancesRepository? balancesRepository,
  }) {
    return ProviderScope(
      overrides: [
        invitationsRepositoryProvider.overrideWithValue(
          FakeInvitationsRepository(),
        ),
        guestClaimsRepositoryProvider.overrideWithValue(
          FakeGuestClaimsRepository(),
        ),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(restoredUser: testUser),
        ),
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(currentProfile: completedTestProfile),
        ),
        groupsRepositoryProvider.overrideWithValue(groupsRepository),
        expensesRepositoryProvider.overrideWithValue(
          expensesRepository ?? FakeExpensesRepository(),
        ),
        balancesRepositoryProvider.overrideWithValue(
          balancesRepository ?? FakeBalancesRepository(),
        ),
        settlementsRepositoryProvider.overrideWithValue(
          FakeSettlementsRepository(),
        ),
        expenseActivityRepositoryProvider.overrideWithValue(
          FakeExpenseActivityRepository(),
        ),
      ],
      child: const OweLoopBootstrap(),
    );
  }

  Future<void> pumpApp(
    WidgetTester tester,
    FakeGroupsRepository groupsRepository, {
    FakeExpensesRepository? expensesRepository,
    FakeBalancesRepository? balancesRepository,
  }) async {
    await tester.pumpWidget(
      buildApp(
        groupsRepository,
        expensesRepository: expensesRepository,
        balancesRepository: balancesRepository,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCreateGroup(
    WidgetTester tester,
    FakeGroupsRepository groupsRepository,
  ) async {
    await pumpApp(tester, groupsRepository);
    final emptyStateAction = find.text('Create your first group');
    await tester.tap(
      emptyStateAction.evaluate().isNotEmpty
          ? emptyStateAction
          : find.text('Create group').first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a useful empty group state', (tester) async {
    await pumpApp(tester, FakeGroupsRepository());

    expect(find.text('Hi, Taylor'), findsOneWidget);
    expect(find.text('Create your first group'), findsOneWidget);
  });

  testWidgets('archived owner can confirm reopening without losing history', (
    tester,
  ) async {
    final archived = AppGroup(
      id: testGroup.id,
      name: testGroup.name,
      currencyCode: 'AUD',
      currentUserRole: GroupRole.owner,
      archivedAt: DateTime.utc(2026),
    );
    final repository = FakeGroupsRepository(
      groups: [archived],
      groupsById: {archived.id: archived},
      membersByGroupId: {
        archived.id: [testOwnerMember, testGuestMember],
      },
    );
    await pumpApp(tester, repository);
    await tester.tap(find.text(testGroup.name));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Group settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reopen group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reopen group'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Balances and history stay unchanged'),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Reopen group'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.reopenCalls, 1);
    expect(repository.groupsById[testGroup.id]!.isArchived, isFalse);
  });

  testWidgets('shows a loading group state', (tester) async {
    final completer = Completer<List<AppGroup>>();
    final repository = FakeGroupsRepository()
      ..loadGroupsHandler = () => completer.future;

    await tester.pumpWidget(buildApp(repository));
    await tester.pump();
    await tester.pump();

    expect(find.byType(GroupLoadingView), findsOneWidget);
    completer.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('shows groups and opens their detail screen', (tester) async {
    final repository = FakeGroupsRepository(groups: const [testGroup])
      ..groupsById[testGroup.id] = testGroup
      ..membersByGroupId[testGroup.id] = const [
        testOwnerMember,
        testGuestMember,
      ];
    await pumpApp(tester, repository);

    expect(find.text('Weekend trip'), findsOneWidget);
    expect(find.text('AUD · Owner'), findsOneWidget);
    await tester.tap(find.text('Weekend trip'));
    await tester.pumpAndSettle();

    expect(find.text('Your role: Owner'), findsOneWidget);
    expect(find.text('Balances'), findsOneWidget);
    expect(find.text('You are settled up'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Taylor'), 240);
    expect(find.text('Taylor'), findsOneWidget);
    expect(find.text('Morgan'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Expense history'), 240);
    expect(find.text('Expense history'), findsOneWidget);
  });

  testWidgets('keeps archived groups available as clearly read-only history', (
    tester,
  ) async {
    final archivedGroup = AppGroup(
      id: 'archived-group',
      name: 'Past holiday',
      currencyCode: 'AUD',
      currentUserRole: GroupRole.owner,
      archivedAt: DateTime.utc(2026, 8, 15),
    );
    final repository = FakeGroupsRepository(groups: [testGroup, archivedGroup])
      ..groupsById[testGroup.id] = testGroup
      ..groupsById[archivedGroup.id] = archivedGroup
      ..membersByGroupId[archivedGroup.id] = const [testOwnerMember];

    await pumpApp(tester, repository);

    expect(find.text('Archived groups'), findsOneWidget);
    expect(find.text('Past holiday'), findsOneWidget);
    expect(find.text('AUD · Owner · Archived'), findsOneWidget);
  });

  testWidgets('shows current, guest, and removed member balances', (
    tester,
  ) async {
    final groupsRepository = FakeGroupsRepository(groups: const [testGroup])
      ..groupsById[testGroup.id] = testGroup
      ..membersByGroupId[testGroup.id] = const [
        testOwnerMember,
        testGuestMember,
      ];
    final balancesRepository = FakeBalancesRepository(
      balances: const [
        testRemovedGuestBalance,
        testGuestOwingBalance,
        testCurrentOwedBalance,
      ],
    );
    await pumpApp(
      tester,
      groupsRepository,
      balancesRepository: balancesRepository,
    );
    await tester.tap(find.text('Weekend trip'));
    await tester.pumpAndSettle();

    expect(find.text('You are owed AUD 30.00'), findsOneWidget);
    expect(find.text('Taylor is owed AUD 30.00'), findsOneWidget);
    expect(find.text('Morgan owes AUD 30.00'), findsOneWidget);
    expect(find.text('Robin owes AUD 2.00'), findsOneWidget);
    expect(find.text('Removed'), findsOneWidget);
    expect(find.text('Guest'), findsWidgets);
  });

  testWidgets('offers a repayment suggestion that opens a settlement record', (
    tester,
  ) async {
    const owingMember = GroupMember(
      id: 'owing-member',
      displayName: 'Alex',
      role: GroupRole.member,
      userId: 'alex-user',
    );
    const owingBalance = GroupBalance(
      groupMemberId: 'owing-member',
      displayName: 'Alex',
      role: GroupRole.member,
      isRemoved: false,
      isGuest: false,
      isCurrentUser: false,
      netBalance: ExactMoney(currencyCode: 'AUD', minorUnits: -1250),
    );
    const owedBalance = GroupBalance(
      groupMemberId: 'owner-member',
      displayName: 'Taylor',
      role: GroupRole.owner,
      isRemoved: false,
      isGuest: false,
      isCurrentUser: true,
      netBalance: ExactMoney(currencyCode: 'AUD', minorUnits: 1250),
    );
    final groupsRepository = FakeGroupsRepository(groups: const [testGroup])
      ..groupsById[testGroup.id] = testGroup
      ..membersByGroupId[testGroup.id] = const [testOwnerMember, owingMember];
    final balancesRepository = FakeBalancesRepository(
      balances: const [owedBalance, owingBalance],
    );
    await pumpApp(
      tester,
      groupsRepository,
      balancesRepository: balancesRepository,
    );
    await tester.tap(find.text('Weekend trip'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Repayment suggestions'), 240);
    expect(find.text('Alex pays Taylor'), findsOneWidget);
    final recordButton = find.widgetWithText(OutlinedButton, 'Record');
    await tester.scrollUntilVisible(recordButton, 120);
    await tester.ensureVisible(recordButton);
    await tester.pumpAndSettle();
    await tester.tap(recordButton);
    await tester.pumpAndSettle();

    expect(find.text('Record a repayment'), findsOneWidget);
    final amountField = find.byKey(const Key('settlement-amount-input'));
    expect(tester.widget<TextFormField>(amountField).controller?.text, '12.50');
  });

  testWidgets('shows a loading balance state until the ledger is available', (
    tester,
  ) async {
    final groupsRepository = FakeGroupsRepository(groups: const [testGroup])
      ..groupsById[testGroup.id] = testGroup
      ..membersByGroupId[testGroup.id] = const [testOwnerMember];
    final balanceCompleter = Completer<List<GroupBalance>>();
    final balancesRepository = FakeBalancesRepository()
      ..loadBalancesHandler = () => balanceCompleter.future;

    await pumpApp(
      tester,
      groupsRepository,
      balancesRepository: balancesRepository,
    );
    await tester.tap(find.text('Weekend trip'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Loading balances',
      ),
      findsOneWidget,
    );
    balanceCompleter.complete(const [testCurrentSettledBalance]);
    await tester.pumpAndSettle();

    expect(find.text('You are settled up'), findsOneWidget);
  });

  testWidgets('shows a safe balance error and retries the balance read', (
    tester,
  ) async {
    final groupsRepository = FakeGroupsRepository(groups: const [testGroup])
      ..groupsById[testGroup.id] = testGroup
      ..membersByGroupId[testGroup.id] = const [testOwnerMember];
    final balancesRepository = FakeBalancesRepository()
      ..loadBalancesError = Exception('network timeout');

    await pumpApp(
      tester,
      groupsRepository,
      balancesRepository: balancesRepository,
    );
    await tester.tap(find.text('Weekend trip'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'We could not reach OweLoop. Check your connection and try again.',
      ),
      findsOneWidget,
    );

    balancesRepository
      ..loadBalancesError = null
      ..balances = const [testCurrentOwingBalance];
    await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(find.text('You owe AUD 12.50'), findsOneWidget);
    expect(balancesRepository.loadBalancesCalls, 2);
  });

  testWidgets('shows an error and retries the group list', (tester) async {
    final repository = FakeGroupsRepository()
      ..loadGroupsError = Exception('network failure');
    await pumpApp(tester, repository);

    expect(find.text('We could not load your groups'), findsOneWidget);
    repository
      ..loadGroupsError = null
      ..groups = const [testGroup];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Weekend trip'), findsOneWidget);
  });

  testWidgets('validates the create-group form and currency selection', (
    tester,
  ) async {
    await openCreateGroup(tester, FakeGroupsRepository());

    await tester.tap(find.widgetWithText(FilledButton, 'Create group'));
    await tester.pump();
    expect(find.text('Enter a group name.'), findsOneWidget);
    expect(find.text('Choose a currency.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Weekend trip');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AUD').last);
    await tester.pumpAndSettle();

    expect(find.text('AUD'), findsWidgets);
  });

  testWidgets('disables creation while a group request is in progress', (
    tester,
  ) async {
    final completer = Completer<AppGroup>();
    final repository = FakeGroupsRepository();
    repository.createGroupHandler = (_) => completer.future;
    repository.groups = const [testGroup];
    repository.groupsById[testGroup.id] = testGroup;
    repository.membersByGroupId[testGroup.id] = const [testOwnerMember];
    await openCreateGroup(tester, repository);

    await tester.enterText(find.byType(TextFormField), 'Weekend trip');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AUD').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create group'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(testGroup);
    await tester.pumpAndSettle();
    expect(find.text('Your role: Owner'), findsOneWidget);
  });

  testWidgets('validates and safely reports guest creation errors', (
    tester,
  ) async {
    final repository = FakeGroupsRepository(groups: const [testGroup])
      ..groupsById[testGroup.id] = testGroup
      ..membersByGroupId[testGroup.id] = const [testOwnerMember]
      ..addGuestError = Exception('network failure');
    await pumpApp(tester, repository);
    await tester.tap(find.text('Weekend trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add guest'));
    await tester.pumpAndSettle();

    final addGuestButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Add guest'),
    );
    await tester.ensureVisible(addGuestButton);
    await tester.tap(addGuestButton);
    await tester.pump();
    expect(find.text('Enter a guest name.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Morgan');
    await tester.ensureVisible(addGuestButton);
    await tester.tap(addGuestButton);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'We could not reach OweLoop. Check your connection and try again.',
      ),
      findsOneWidget,
    );
  });
}
