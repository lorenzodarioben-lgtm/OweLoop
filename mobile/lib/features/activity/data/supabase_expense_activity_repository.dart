import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/expense_activity_models.dart';
import 'expense_activity_repository.dart';

class SupabaseExpenseActivityRepository implements ExpenseActivityRepository {
  SupabaseExpenseActivityRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ExpenseActivityEvent>> loadExpenseActivity({
    required String expenseId,
    required String currencyCode,
  }) async {
    final rows = await _client.rpc(
      'get_expense_activity',
      params: <String, dynamic>{'p_expense_id': expenseId},
    );
    return (rows as List)
        .map(
          (row) => ExpenseActivityEvent.fromMap(
            Map<String, dynamic>.from(row),
            currencyCode: currencyCode,
          ),
        )
        .toList();
  }
}
