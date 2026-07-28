import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/expenses/data/supabase_expenses_repository.dart';
import 'package:oweloop/features/expenses/domain/exact_money.dart';
import 'package:oweloop/features/expenses/domain/expense_models.dart';
import 'package:oweloop/features/expenses/state/expenses_controller.dart';
import 'package:oweloop/features/expenses/state/expenses_state.dart';

import '../../fakes/expenses_fakes.dart';

void main() {
  late FakeExpensesRepository repository;

  setUp(() {
    repository = FakeExpensesRepository();
  });

  test('loads empty and populated expense histories', () async {
    final controller = ExpenseHistoryController(
      groupId: testExpense.groupId,
      repository: repository,
    );

    await controller.load();
    expect(controller.state.status, ExpenseHistoryStatus.ready);
    expect(controller.state.expenses, isEmpty);

    repository.expenses = [testExpense];
    await controller.refresh();
    expect(controller.state.expenses, [testExpense]);
  });

  test('does not restore stale history after sign-out cleanup', () async {
    final completer = Completer<List<ExpenseRecord>>();
    repository.loadExpensesHandler = () => completer.future;
    final controller = ExpenseHistoryController(
      groupId: testExpense.groupId,
      repository: repository,
    );

    final pendingLoad = controller.load();
    controller.clear();
    completer.complete([testExpense]);
    await pendingLoad;

    expect(controller.state.status, ExpenseHistoryStatus.loading);
    expect(controller.state.expenses, isEmpty);
  });

  test(
    'creates an expense and supports history refresh after creation',
    () async {
      repository.createdExpense = testExpense;
      final historyController = ExpenseHistoryController(
        groupId: testExpense.groupId,
        repository: repository,
      );
      final creationController = ExpenseCreationController(repository);
      await historyController.load();

      final created = await creationController.create(
        ExpenseCreationInput(
          groupId: testExpense.groupId,
          description: ' Dinner ',
          total: const ExactMoney(currencyCode: 'AUD', minorUnits: 1000),
          occurredAt: DateTime.utc(2026, 7, 29, 12),
          payerMemberId: 'owner-member',
          participantMemberIds: const ['owner-member', 'guest-member'],
        ),
      );
      repository.expenses = [testExpense];
      await historyController.refresh();

      expect(created, testExpense);
      expect(repository.lastCreationInput?.trimmedDescription, 'Dinner');
      expect(historyController.state.expenses, [testExpense]);
    },
  );

  test('surfaces safe expense creation errors', () async {
    repository.createExpenseError = const ExpensesRepositoryException(
      'Expense total must be greater than zero',
    );
    final controller = ExpenseCreationController(repository);

    final created = await controller.create(
      ExpenseCreationInput(
        groupId: testExpense.groupId,
        description: 'Dinner',
        total: const ExactMoney(currencyCode: 'AUD', minorUnits: 1000),
        occurredAt: DateTime.utc(2026, 7, 29, 12),
        payerMemberId: 'owner-member',
        participantMemberIds: const ['owner-member'],
      ),
    );

    expect(created, isNull);
    expect(controller.state.errorMessage, 'Enter a valid positive amount.');
  });

  test(
    'loads details and treats inaccessible expenses as unavailable',
    () async {
      repository.expensesById[testExpense.id] = testExpense;
      final controller = ExpenseDetailController(
        groupId: testExpense.groupId,
        expenseId: testExpense.id,
        repository: repository,
      );

      await controller.load();
      expect(controller.state.status, ExpenseDetailStatus.ready);
      expect(controller.state.expense, testExpense);

      final unavailable = ExpenseDetailController(
        groupId: testExpense.groupId,
        expenseId: 'missing-expense',
        repository: repository,
      );
      await unavailable.load();
      expect(unavailable.state.status, ExpenseDetailStatus.unavailable);

      final mismatchedRoute = ExpenseDetailController(
        groupId: 'different-group',
        expenseId: testExpense.id,
        repository: repository,
      );
      await mismatchedRoute.load();
      expect(mismatchedRoute.state.status, ExpenseDetailStatus.unavailable);
    },
  );
}
