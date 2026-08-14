import '../domain/expense_models.dart';

abstract interface class ExpensesRepository {
  Future<List<ExpenseRecord>> loadPostedExpenses(String groupId);

  Future<ExpenseRecord> createExpense(ExpenseCreationInput input);

  Future<ExpenseRecord> voidExpense({
    required String expenseId,
    required String currencyCode,
  });

  Future<ExpenseRecord?> loadAccessibleExpense(String expenseId);
}
