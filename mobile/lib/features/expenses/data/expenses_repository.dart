import '../domain/expense_models.dart';
import '../../../core/operations/history_page.dart';

abstract interface class PagedExpensesRepository implements ExpensesRepository {
  Future<HistoryPage<ExpenseRecord>> loadExpensePage(
    String groupId, {
    HistoryCursor? before,
    ExpenseHistoryFilter filter = const ExpenseHistoryFilter(),
  });
}

abstract interface class ExpensesRepository {
  Future<List<ExpenseRecord>> loadPostedExpenses(String groupId);

  Future<ExpenseRecord> createExpense(ExpenseCreationInput input);

  Future<ExpenseRecord> voidExpense({
    required String expenseId,
    required String currencyCode,
  });

  Future<ExpenseRecord?> loadAccessibleExpense(String expenseId);
}
