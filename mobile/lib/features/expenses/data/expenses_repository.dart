import '../domain/expense_models.dart';

abstract interface class ExpensesRepository {
  Future<List<ExpenseRecord>> loadPostedExpenses(String groupId);

  Future<ExpenseRecord> createExpense(ExpenseCreationInput input);

  Future<ExpenseRecord?> loadAccessibleExpense(String expenseId);
}
