import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/expense_template.dart';
import '../../authentication/state/authentication_providers.dart';

abstract interface class ExpenseTemplatesRepository {
  Future<List<ExpenseTemplate>> load(String groupId);
  Future<void> save({
    required String groupId,
    required String name,
    required Map<String, dynamic> fields,
    ExpenseTemplate? previous,
  });
  Future<void> delete(ExpenseTemplate template);
}

class SupabaseExpenseTemplatesRepository implements ExpenseTemplatesRepository {
  SupabaseExpenseTemplatesRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<ExpenseTemplate>> load(String groupId) async {
    final rows = await client.rpc(
      'get_expense_templates',
      params: {'p_group_id': groupId},
    );
    return (rows as List)
        .map(
          (dynamic row) =>
              ExpenseTemplate.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  @override
  Future<void> save({
    required String groupId,
    required String name,
    required Map<String, dynamic> fields,
    ExpenseTemplate? previous,
  }) async {
    await client.rpc(
      'save_expense_template',
      params: {
        'p_group_id': groupId,
        'p_name': name,
        'p_payload': Map<String, dynamic>.from(fields)..remove('occurred_on'),
        'p_template_id': previous?.id,
        'p_expected_updated_at': previous?.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<void> delete(ExpenseTemplate template) async {
    await client.rpc(
      'delete_expense_template',
      params: {
        'p_template_id': template.id,
        'p_expected_updated_at': template.updatedAt.toUtc().toIso8601String(),
      },
    );
  }
}

String templateErrorMessage(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('changed; reload')) {
    return 'This template changed. Reload it before editing or deleting.';
  }
  if (text.contains('already exists') || text.contains('23505')) {
    return 'A template with that name already exists. Choose a different name.';
  }
  if (text.contains('archived')) {
    return 'Archived group templates are read only. Ask the owner to reopen the group.';
  }
  if (text.contains('active in this group') ||
      text.contains('allocation member')) {
    return 'A saved participant is no longer active. Reload the form and review members.';
  }
  if (text.contains('invalid template') ||
      text.contains('template amount') ||
      text.contains('template name')) {
    return 'Review the template name, description, category and amount. No expense was posted.';
  }
  return 'The template could not be loaded or changed. Check your connection and group permissions, then retry.';
}

final expenseTemplatesRepositoryProvider = Provider<ExpenseTemplatesRepository>(
  (ref) => SupabaseExpenseTemplatesRepository(Supabase.instance.client),
);
final expenseTemplatesProvider = FutureProvider.autoDispose
    .family<List<ExpenseTemplate>, String>((ref, id) {
      final user = ref.watch(authenticationControllerProvider).state.user;
      if (user == null) return [];
      return ref.watch(expenseTemplatesRepositoryProvider).load(id);
    });
