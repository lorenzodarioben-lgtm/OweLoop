import 'package:oweloop/features/activity/data/expense_activity_repository.dart';
import 'package:oweloop/features/activity/domain/expense_activity_models.dart';

class FakeExpenseActivityRepository implements ExpenseActivityRepository {
  List<ExpenseActivityEvent> events = const [];
  Object? error;

  @override
  Future<List<ExpenseActivityEvent>> loadExpenseActivity({
    required String expenseId,
    required String currencyCode,
  }) async {
    if (error != null) throw error!;
    return events;
  }
}
