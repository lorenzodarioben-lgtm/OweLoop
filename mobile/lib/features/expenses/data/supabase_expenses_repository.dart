import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/operations/history_page.dart';
import '../../../core/operations/pending_financial_operations.dart';

import '../domain/expense_models.dart';
import 'expenses_repository.dart';

class SupabaseExpensesRepository implements PagedExpensesRepository {
  SupabaseExpensesRepository(this._client, {this.operations});

  final SupabaseClient _client;
  final PendingFinancialOperations? operations;

  @override
  Future<List<ExpenseRecord>> loadPostedExpenses(String groupId) async {
    final rows = await _client.rpc(
      'get_group_expense_export_snapshot',
      params: {'p_group_id': groupId},
    );
    return (rows as List)
        .map(
          (dynamic row) =>
              ExpenseRecord.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  @override
  Future<HistoryPage<ExpenseRecord>> loadExpensePage(
    String groupId, {
    HistoryCursor? before,
    ExpenseHistoryFilter filter = const ExpenseHistoryFilter(),
  }) async {
    final rows = await _client.rpc(
      'get_categorized_expense_page',
      params: {
        'p_group_id': groupId,
        'p_limit': 50,
        ...filter.params,
        ...?before?.params('p_before_occurred_at'),
      },
    );
    final maps = (rows as List)
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final visible = maps.take(50).toList();
    final last = visible.isEmpty ? null : visible.last;
    return HistoryPage(
      items: visible.map(ExpenseRecord.fromMap).toList(),
      next: maps.length > 50 && last != null
          ? HistoryCursor(
              occurredAt: DateTime.parse(last['occurred_at'] as String),
              createdAt: DateTime.parse(last['created_at'] as String),
              id: last['id'] as String,
            )
          : null,
    );
  }

  @override
  Future<ExpenseRecord> createExpense(ExpenseCreationInput input) async {
    final params = <String, dynamic>{
      'p_group_id': input.groupId,
      'p_description': input.trimmedDescription,
      if (input.category != null) 'p_category_key': input.category!.name,
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
    };
    final row = operations == null
        ? await _client
              .rpc(
                input.category == null
                    ? 'create_expense'
                    : 'create_categorized_expense',
                params: {...params, 'p_operation_id': input.operationId},
              )
              .single()
        : await operations!.execute(
            requestedOperationId: input.operationId,
            type: 'expense',
            groupId: input.groupId,
            payload: params,
          );

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
          'id, group_id, description, category_key, total_amount_minor, occurred_at, status, voided_at, '
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
