import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/core/operations/history_page.dart';
import 'package:oweloop/features/expenses/data/expenses_repository.dart';
import 'package:oweloop/features/expenses/domain/expense_models.dart';
import 'package:oweloop/features/expenses/state/expenses_controller.dart';
import '../../fakes/expenses_fakes.dart';

class PagedFake extends FakeExpensesRepository
    implements PagedExpensesRepository {
  late Future<HistoryPage<ExpenseRecord>> Function(
    HistoryCursor?,
    ExpenseHistoryFilter,
  )
  page;
  @override
  Future<HistoryPage<ExpenseRecord>> loadExpensePage(
    String groupId, {
    HistoryCursor? before,
    ExpenseHistoryFilter filter = const ExpenseHistoryFilter(),
  }) => page(before, filter);
}

void main() {
  final cursor = HistoryCursor(
    occurredAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    id: 'expense-1',
  );
  test(
    'page boundaries deduplicate records and preserve the next cursor',
    () async {
      final older = ExpenseRecord(
        id: 'older',
        groupId: testExpense.groupId,
        description: 'Older',
        total: testExpense.total,
        occurredAt: DateTime.utc(2025),
        status: ExpenseStatus.posted,
      );
      final repository = PagedFake()
        ..page = (before, filter) async => before == null
            ? HistoryPage(items: [testExpense], next: cursor)
            : HistoryPage(items: [testExpense, older]);
      final controller = ExpenseHistoryController(
        groupId: testExpense.groupId,
        repository: repository,
      );
      await controller.load();
      expect(controller.state.hasMore, isTrue);
      await controller.loadMore();
      expect(controller.state.expenses.map((row) => row.id), [
        testExpense.id,
        older.id,
      ]);
      expect(controller.state.hasMore, isFalse);
      controller.dispose();
    },
  );
  test(
    'filter changes invalidate an in-flight older page and reset the cursor',
    () async {
      final pending = Completer<HistoryPage<ExpenseRecord>>();
      final repository = PagedFake()
        ..page = (before, filter) async {
          if (before != null) return pending.future;
          return filter.query.isEmpty
              ? HistoryPage(items: [testExpense], next: cursor)
              : const HistoryPage(items: []);
        };
      final controller = ExpenseHistoryController(
        groupId: testExpense.groupId,
        repository: repository,
      );
      await controller.load();
      final more = controller.loadMore();
      await controller.filter(const ExpenseHistoryFilter(query: 'different'));
      pending.complete(HistoryPage(items: [testExpense]));
      await more;
      expect(controller.state.expenses, isEmpty);
      expect(controller.state.hasMore, isFalse);
      controller.dispose();
    },
  );
  test(
    'sign-out invalidates a pending page without restoring private rows',
    () async {
      final pending = Completer<HistoryPage<ExpenseRecord>>();
      final repository = PagedFake()..page = (before, filter) => pending.future;
      final controller = ExpenseHistoryController(
        groupId: testExpense.groupId,
        repository: repository,
      );
      final loading = controller.load();
      controller.clear();
      pending.complete(HistoryPage(items: [testExpense]));
      await loading;
      expect(controller.state.expenses, isEmpty);
      controller.dispose();
    },
  );
}
