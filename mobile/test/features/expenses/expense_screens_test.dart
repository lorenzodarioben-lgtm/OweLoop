import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/app/app_bootstrap.dart';
import 'package:oweloop/features/authentication/state/authentication_providers.dart';
import 'package:oweloop/features/activity/state/expense_activity_providers.dart';
import 'package:oweloop/features/balances/state/balances_providers.dart';
import 'package:oweloop/features/expenses/domain/expense_models.dart';
import 'package:oweloop/features/expenses/state/expenses_providers.dart';
import 'package:oweloop/features/groups/state/groups_providers.dart';
import 'package:oweloop/features/settlements/state/settlements_providers.dart';

import '../../fakes/authentication_fakes.dart';
import '../../fakes/activity_fakes.dart';
import '../../fakes/balances_fakes.dart';
import '../../fakes/expenses_fakes.dart';
import '../../fakes/groups_fakes.dart';
import '../../fakes/settlements_fakes.dart';

void main() {
  FakeGroupsRepository groupRepository() {
    return FakeGroupsRepository(groups: const [testGroup])
      ..groupsById[testGroup.id] = testGroup
      ..membersByGroupId[testGroup.id] = const [
        testOwnerMember,
        testGuestMember,
      ];
  }

  Widget buildApp({
    required FakeGroupsRepository groupsRepository,
    required FakeExpensesRepository expensesRepository,
    FakeBalancesRepository? balancesRepository,
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
        expensesRepositoryProvider.overrideWithValue(expensesRepository),
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

  Future<void> openGroup(
    WidgetTester tester, {
    required FakeGroupsRepository groupsRepository,
    required FakeExpensesRepository expensesRepository,
    FakeBalancesRepository? balancesRepository,
  }) async {
    await tester.pumpWidget(
      buildApp(
        groupsRepository: groupsRepository,
        expensesRepository: expensesRepository,
        balancesRepository: balancesRepository,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekend trip'));
    await tester.pumpAndSettle();
  }

  Future<void> openExpenseForm(
    WidgetTester tester, {
    required FakeGroupsRepository groupsRepository,
    required FakeExpensesRepository expensesRepository,
    FakeBalancesRepository? balancesRepository,
  }) async {
    await openGroup(
      tester,
      groupsRepository: groupsRepository,
      expensesRepository: expensesRepository,
      balancesRepository: balancesRepository,
    );
    await tester.tap(find.text('Add expense').first);
    await tester.pumpAndSettle();
  }

  Future<void> enterValidExpense(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Dinner');
    await tester.enterText(fields.at(1), '10.00');
    await tester.pump();
  }

  Future<void> tapPostExpense(WidgetTester tester) async {
    final postExpense = find.widgetWithText(FilledButton, 'Post expense');
    await tester.ensureVisible(postExpense);
    await tester.tap(postExpense);
  }

  Future<void> deselectGuestParticipant(WidgetTester tester) async {
    final guestParticipant = find.byType(CheckboxListTile).last;
    await tester.ensureVisible(guestParticipant);
    await tester.tap(guestParticipant);
  }

  testWidgets('shows an empty expense history and add action', (tester) async {
    await openGroup(
      tester,
      groupsRepository: groupRepository(),
      expensesRepository: FakeExpensesRepository(),
    );

    await tester.scrollUntilVisible(find.text('Expense history'), 240);
    expect(find.text('Expense history'), findsOneWidget);
    expect(find.text('No posted expenses yet.'), findsOneWidget);
    expect(find.text('Add expense'), findsWidgets);
  });

  testWidgets('renders expense history and accessible expense details', (
    tester,
  ) async {
    final expensesRepository = FakeExpensesRepository(
      expenses: [testExpense],
      expensesById: <String, ExpenseRecord>{testExpense.id: testExpense},
    );
    await openGroup(
      tester,
      groupsRepository: groupRepository(),
      expensesRepository: expensesRepository,
    );

    final dinnerTile = find.ancestor(
      of: find.text('Dinner'),
      matching: find.byType(ListTile),
    );
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('AUD 10.00'), findsOneWidget);
    await tester.tap(dinnerTile);
    await tester.pumpAndSettle();

    expect(find.text('Expense details'), findsOneWidget);
    expect(find.text('Taylor paid AUD 10.00'), findsOneWidget);
    expect(find.text('Morgan'), findsOneWidget);
    expect(find.text('Posted'), findsOneWidget);
  });

  testWidgets('validates the expense form and previews equal splits', (
    tester,
  ) async {
    await openExpenseForm(
      tester,
      groupsRepository: groupRepository(),
      expensesRepository: FakeExpensesRepository(),
    );

    await tapPostExpense(tester);
    await tester.pump();
    expect(find.text('Enter an expense description.'), findsOneWidget);
    expect(
      find.text('Enter an amount with up to 2 decimal places.'),
      findsOneWidget,
    );

    await enterValidExpense(tester);
    expect(find.text('Equal split preview'), findsOneWidget);
    expect(find.text('AUD 5.00'), findsNWidgets(2));
    expect(
      find.bySemanticsLabel('Post expense with exact allocation'),
      findsOneWidget,
    );

    await deselectGuestParticipant(tester);
    await tester.pump();
    expect(find.text('AUD 10.00'), findsOneWidget);
  });

  testWidgets('creates an expense, refreshes history, and opens details', (
    tester,
  ) async {
    final expensesRepository = FakeExpensesRepository(
      expensesById: <String, ExpenseRecord>{testExpense.id: testExpense},
    );
    expensesRepository.createHandler = (input) async {
      expensesRepository.expenses = [testExpense];
      return testExpense;
    };
    final balancesRepository = FakeBalancesRepository();
    await openExpenseForm(
      tester,
      groupsRepository: groupRepository(),
      expensesRepository: expensesRepository,
      balancesRepository: balancesRepository,
    );
    await enterValidExpense(tester);
    await deselectGuestParticipant(tester);
    await tester.pump();
    await tapPostExpense(tester);
    await tester.pumpAndSettle();

    expect(expensesRepository.lastCreationInput?.total.minorUnits, 1000);
    expect(expensesRepository.lastCreationInput?.participantMemberIds, const [
      'owner-member',
    ]);
    expect(
      expensesRepository.lastCreationInput?.operationId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(expensesRepository.loadExpensesCalls, greaterThanOrEqualTo(2));
    expect(balancesRepository.loadBalancesCalls, greaterThanOrEqualTo(2));
    expect(find.text('Expense details'), findsOneWidget);
  });

  testWidgets('shows safe creation errors and disables repeated submission', (
    tester,
  ) async {
    final creationCompleter = Completer<ExpenseRecord>();
    final expensesRepository = FakeExpensesRepository()
      ..createHandler = (_) => creationCompleter.future;
    await openExpenseForm(
      tester,
      groupsRepository: groupRepository(),
      expensesRepository: expensesRepository,
    );
    await enterValidExpense(tester);
    await tapPostExpense(tester);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    creationCompleter.complete(testExpense);
    await tester.pumpAndSettle();
  });

  testWidgets('shows a safe failed creation message', (tester) async {
    final expensesRepository = FakeExpensesRepository()
      ..createExpenseError = Exception('network failure');
    await openExpenseForm(
      tester,
      groupsRepository: groupRepository(),
      expensesRepository: expensesRepository,
    );
    await enterValidExpense(tester);
    await tapPostExpense(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'We could not reach OweLoop. Check your connection and try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reuses an operation ID when a financial submission is retried', (
    tester,
  ) async {
    var attempts = 0;
    final expensesRepository = FakeExpensesRepository()
      ..createHandler = (input) async {
        attempts += 1;
        if (attempts == 1) throw Exception('network timeout');
        return testExpense;
      };
    await openExpenseForm(
      tester,
      groupsRepository: groupRepository(),
      expensesRepository: expensesRepository,
    );
    await enterValidExpense(tester);

    await tapPostExpense(tester);
    await tester.pumpAndSettle();
    await tapPostExpense(tester);
    await tester.pumpAndSettle();

    expect(expensesRepository.creationInputs, hasLength(2));
    expect(
      expensesRepository.creationInputs[1].operationId,
      expensesRepository.creationInputs.first.operationId,
    );
  });
}
