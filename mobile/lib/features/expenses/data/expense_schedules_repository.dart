import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/expense_schedule.dart';

abstract interface class ExpenseSchedulesRepository {
  Future<ExpenseSchedulePage> load(
    String groupId, {
    String? beforeDate,
    String? beforeId,
  });
  Future<void> create(String templateId, Map<String, dynamic> configuration);
  Future<void> update(
    ExpenseSchedule schedule,
    Map<String, dynamic> configuration, {
    bool cancel = false,
  });
  Future<void> skip(String occurrenceId);
}

class SupabaseExpenseSchedulesRepository implements ExpenseSchedulesRepository {
  SupabaseExpenseSchedulesRepository(this.client);
  final SupabaseClient client;
  @override
  Future<ExpenseSchedulePage> load(
    String groupId, {
    String? beforeDate,
    String? beforeId,
  }) async {
    final result =
        await client.rpc(
              'get_expense_schedule_page',
              params: {
                'p_group_id': groupId,
                'p_before_date': beforeDate,
                'p_before_id': beforeId,
              },
            )
            as Map;
    final all = (result['occurrences'] as List)
        .map(
          (dynamic row) =>
              ExpenseOccurrence.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
    final visible = all.take(50).toList();
    return ExpenseSchedulePage(
      (result['schedules'] as List)
          .map(
            (dynamic row) =>
                ExpenseSchedule.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
      visible,
      nextDate: all.length > 50 ? visible.last.dueDate : null,
      nextId: all.length > 50 ? visible.last.id : null,
    );
  }

  @override
  Future<void> create(
    String templateId,
    Map<String, dynamic> configuration,
  ) async {
    await client.rpc(
      'create_expense_schedule',
      params: {'p_template_id': templateId, ...configuration},
    );
  }

  @override
  Future<void> update(
    ExpenseSchedule schedule,
    Map<String, dynamic> configuration, {
    bool cancel = false,
  }) async {
    await client.rpc(
      'update_expense_schedule',
      params: {
        'p_schedule_id': schedule.id,
        'p_expected_revision': schedule.revision,
        'p_cancel': cancel,
        ...configuration,
      },
    );
  }

  @override
  Future<void> skip(String occurrenceId) async {
    await client.rpc(
      'skip_expense_occurrence',
      params: {'p_occurrence_id': occurrenceId},
    );
  }
}

final expenseSchedulesRepositoryProvider = Provider<ExpenseSchedulesRepository>(
  (ref) => SupabaseExpenseSchedulesRepository(Supabase.instance.client),
);
