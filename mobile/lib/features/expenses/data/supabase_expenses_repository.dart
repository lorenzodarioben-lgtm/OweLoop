import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/expense_models.dart';
import 'expenses_repository.dart';

class SupabaseExpensesRepository implements ExpensesRepository {
  SupabaseExpensesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ExpenseRecord>> loadPostedExpenses(String groupId) async {
    final rows = await _client
        .from('expenses')
        .select(
          'id, group_id, description, total_amount_minor, occurred_at, status, voided_at, '
          'groups!inner(currency_code)',
        )
        .eq('group_id', groupId)
        .inFilter('status', const ['posted', 'voided'])
        .order('occurred_at', ascending: false)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => ExpenseRecord.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<ExpenseRecord> createExpense(ExpenseCreationInput input) async {
    final row = await _client
        .rpc(
          'create_expense',
          params: <String, dynamic>{
            'p_group_id': input.groupId,
            'p_description': input.trimmedDescription,
            'p_total_amount_minor': input.total.minorUnits,
            'p_occurred_at': input.occurredAt.toUtc().toIso8601String(),
            'p_payers': [
              for (final payer in input.resolvedPayers)
                <String, dynamic>{
                  'member_id': payer.memberId,
                  'amount_minor': payer.amountMinor,
                },
            ],
            'p_splits': [
              for (final split in input.resolvedSplits)
                <String, dynamic>{
                  'member_id': split.memberId,
                  'amount_minor': split.amountMinor,
                },
            ],
            'p_operation_id': input.operationId,
          },
        )
        .single();

    return ExpenseRecord.fromMap(
      Map<String, dynamic>.from(row),
      currencyCode: input.total.currencyCode,
    );
  }

  @override
  Future<ExpenseRecord?> loadAccessibleExpense(String expenseId) async {
    final row = await _client
        .from('expenses')
        .select(
          'id, group_id, description, total_amount_minor, occurred_at, status, voided_at, '
          'groups!inner(currency_code), '
          'expense_payers(group_member_id, amount_minor, '
          'group_members!inner(display_name)), '
          'expense_splits(group_member_id, amount_minor, '
          'group_members!inner(display_name))',
        )
        .eq('id', expenseId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return ExpenseRecord.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<ExpenseRecord> voidExpense({
    required String expenseId,
    required String currencyCode,
  }) async {
    final row = await _client
        .rpc(
          'void_expense',
          params: <String, dynamic>{'p_expense_id': expenseId},
        )
        .single();
    return ExpenseRecord.fromMap(
      Map<String, dynamic>.from(row),
      currencyCode: currencyCode,
    );
  }
}

class ExpensesRepositoryException implements Exception {
  const ExpensesRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
