import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/app/app_bootstrap.dart';
import 'package:oweloop/features/authentication/state/authentication_providers.dart';
import 'package:oweloop/features/expenses/state/expenses_providers.dart';
import 'package:oweloop/features/groups/domain/group_models.dart';
import 'package:oweloop/features/groups/presentation/group_feedback.dart';
import 'package:oweloop/features/groups/state/groups_providers.dart';

import '../../fakes/authentication_fakes.dart';
import '../../fakes/expenses_fakes.dart';
import '../../fakes/groups_fakes.dart';

void main() {
  Widget buildApp(
    FakeGroupsRepository groupsRepository, {
    FakeExpensesRepository? expensesRepository,
  }) {
    return ProviderScope(
      overrides: [
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
      ],
      child: const OweLoopBootstrap(),
    );
  }

  Future<void> pumpApp(
    WidgetTester tester,
    FakeGroupsRepository groupsRepository, {
    FakeExpensesRepository? expensesRepository,
  }) async {
    await tester.pumpWidget(
      buildApp(groupsRepository, expensesRepository: expensesRepository),
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
    expect(find.text('Taylor'), findsOneWidget);
    expect(find.text('Morgan'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Expense history'), findsOneWidget);
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
