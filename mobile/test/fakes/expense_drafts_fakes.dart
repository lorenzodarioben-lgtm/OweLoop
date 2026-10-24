import 'dart:convert';
import 'package:oweloop/features/expenses/data/expense_draft_store.dart';

class MemoryExpenseDraftStore implements ExpenseDraftStore {
  final Map<(String, String), String> records = {};
  @override
  Future<Map<String, dynamic>?> read(String accountId, String groupId) async {
    final text = records[(accountId, groupId)];
    return text == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(text) as Map);
  }

  @override
  Future<void> write(
    String accountId,
    String groupId,
    Map<String, dynamic> fields,
  ) async {
    records[(accountId, groupId)] = jsonEncode(fields);
  }

  @override
  Future<void> delete(String accountId, String groupId) async {
    records.remove((accountId, groupId));
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    records.removeWhere((key, value) => key.$1 == accountId);
  }
}
