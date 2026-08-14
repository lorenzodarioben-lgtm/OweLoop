import '../domain/expense_activity_models.dart';

abstract interface class ExpenseActivityRepository {
  Future<List<ExpenseActivityEvent>> loadExpenseActivity({
    required String expenseId,
    required String currencyCode,
  });
}
