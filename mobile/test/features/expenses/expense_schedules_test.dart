import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/app/app_bootstrap.dart';
import 'package:oweloop/features/authentication/state/authentication_providers.dart';
import 'package:oweloop/features/balances/state/balances_providers.dart';
import 'package:oweloop/features/expenses/data/expense_schedules_repository.dart';
import 'package:oweloop/features/expenses/domain/expense_schedule.dart';
import 'package:oweloop/features/expenses/state/expenses_providers.dart';
import 'package:oweloop/features/groups/state/groups_providers.dart';
import 'package:oweloop/features/settlements/state/settlements_providers.dart';
import '../../fakes/authentication_fakes.dart';
import '../../fakes/balances_fakes.dart';
import '../../fakes/expenses_fakes.dart';
import '../../fakes/groups_fakes.dart';
import '../../fakes/settlements_fakes.dart';

class ScheduleFake implements ExpenseSchedulesRepository {
  bool fail = false;
  int skips = 0;
  Completer<ExpenseSchedulePage>? delayed;
  @override
  Future<ExpenseSchedulePage> load(
    String groupId, {
    String? beforeDate,
    String? beforeId,
  }) async {
    if (fail) throw StateError('offline');
    if (delayed != null) return delayed!.future;
    return ExpenseSchedulePage(
      [
        ExpenseSchedule.fromMap({
          'id': 'schedule',
          'name': 'Rent reminder',
          'template_name': 'Pinned rent',
          'cadence': 'monthly',
          'anchor_date': '2026-01-31',
          'timezone': 'Australia/Sydney',
          'enabled': true,
          'can_edit': true,
          'revision': 1,
          'next_due_date': '2026-11-30',
        }),
      ],
      [
        ExpenseOccurrence.fromMap({
          'id': 'occurrence',
          'name': 'Rent reminder',
          'template_name': 'Pinned rent',
          'due_date': '2026-10-24',
          'state': 'pending',
          'can_review': true,
          'created_at': '2026-10-24T00:00:00Z',
          'payload': {
            'description': 'Reviewed rent',
            'amount': '10.00',
            'split_method': 'equal',
            'single_payer': testOwnerMember.id,
            'participant_ids': [testOwnerMember.id],
          },
        }),
      ],
    );
  }

  @override
  Future<void> create(
    String templateId,
    Map<String, dynamic> configuration,
  ) async {}
  @override
  Future<void> update(
    ExpenseSchedule schedule,
    Map<String, dynamic> configuration, {
    bool cancel = false,
  }) async {}
  @override
  Future<void> skip(String occurrenceId) async {
    skips++;
  }
}

void main() {
  test(
    'calendar entry rejects normalized invalid dates and accepts leap day',
    () {
      expect(calendarDateError('2024-02-29'), isNull);
      expect(calendarDateError('2023-02-29'), isNotNull);
      expect(calendarDateError('2026-13-01'), isNotNull);
      expect(calendarDateError('1999-12-31'), isNotNull);
      expect(calendarDateError('2026-1-1'), isNotNull);
    },
  );
  Future<void> open(
    WidgetTester tester,
    ScheduleFake schedules,
    FakeExpensesRepository expenses,
  ) async {
    final groups = FakeGroupsRepository(groups: const [testGroup])
      ..groupsById[testGroup.id] = testGroup
      ..membersByGroupId[testGroup.id] = const [
        testOwnerMember,
        testGuestMember,
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(restoredUser: testUser),
          ),
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(currentProfile: completedTestProfile),
          ),
          groupsRepositoryProvider.overrideWithValue(groups),
          balancesRepositoryProvider.overrideWithValue(
            FakeBalancesRepository(),
          ),
          settlementsRepositoryProvider.overrideWithValue(
            FakeSettlementsRepository(),
          ),
          expensesRepositoryProvider.overrideWithValue(expenses),
          expenseSchedulesRepositoryProvider.overrideWithValue(schedules),
        ],
        child: const OweLoopBootstrap(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekend trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Recurring drafts'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'review opens ordinary form without posting and retains occurrence identity on explicit post',
    (tester) async {
      final expenses = FakeExpensesRepository();
      await open(tester, ScheduleFake(), expenses);
      expect(
        find.textContaining('Nothing posts automatically'),
        findsOneWidget,
      );
      await tester.tap(find.text('Review expense'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'Reviewed rent'),
        findsOneWidget,
      );
      expect(expenses.lastCreationInput, isNull);
      expect(
        tester
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .enabled,
        isFalse,
      );
      // Leave creation pending so navigation cannot require a real backend.
      expenses.createExpenseError = StateError('offline');
      final post = find.widgetWithText(FilledButton, 'Post expense');
      await tester.ensureVisible(post);
      await tester.tap(post);
      await tester.pumpAndSettle();
      expect(expenses.lastCreationInput?.scheduledOccurrenceId, 'occurrence');
      expect(
        expenses.lastCreationInput?.occurredAt,
        DateTime.utc(2026, 10, 24, 12),
      );
    },
  );
  testWidgets(
    'skip requires confirmation and never posts; refresh errors retain stale warning',
    (tester) async {
      final schedules = ScheduleFake(), expenses = FakeExpensesRepository();
      await open(tester, schedules, expenses);
      await tester.tap(find.text('Skip occurrence'));
      await tester.pumpAndSettle();
      expect(schedules.skips, 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Skip occurrence'));
      await tester.pumpAndSettle();
      expect(schedules.skips, 1);
      expect(expenses.lastCreationInput, isNull);
      schedules.fail = true;
      await tester.tap(find.byTooltip('Refresh recurring drafts'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Displayed data may be stale'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Review expense'),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'recurring drafts remain usable with large text on a small phone',
    (tester) async {
      await open(tester, ScheduleFake(), FakeExpensesRepository());
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
