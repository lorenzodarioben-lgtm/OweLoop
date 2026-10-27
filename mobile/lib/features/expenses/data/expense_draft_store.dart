import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/operations/secure_storage_durability.dart';

abstract interface class ExpenseDraftStore {
  Future<Map<String, dynamic>?> read(String accountId, String groupId);
  Future<void> write(
    String accountId,
    String groupId,
    Map<String, dynamic> fields,
  );
  Future<void> delete(String accountId, String groupId);
  Future<void> deleteAccount(String accountId);
}

class SecureExpenseDraftStore implements ExpenseDraftStore {
  SecureExpenseDraftStore(this.storage, {Future<void> Function()? flush})
    : flush = flush ?? flushSecureStorage;
  final FlutterSecureStorage storage;
  final Future<void> Function() flush;
  String _key(String account, String group) =>
      'oweloop.unsent_expense.v1.$account.$group';
  @override
  Future<Map<String, dynamic>?> read(String accountId, String groupId) async {
    final text = await storage.read(key: _key(accountId, groupId));
    if (text == null) return null;
    final value = jsonDecode(text) as Map<String, dynamic>;
    if (value['version'] != 1 ||
        value['account_id'] != accountId ||
        value['group_id'] != groupId) {
      throw const FormatException('Draft identity could not be verified.');
    }
    return Map<String, dynamic>.from(value['fields'] as Map);
  }

  @override
  Future<void> write(
    String accountId,
    String groupId,
    Map<String, dynamic> fields,
  ) async {
    await storage.write(
      key: _key(accountId, groupId),
      value: jsonEncode({
        'version': 1,
        'account_id': accountId,
        'group_id': groupId,
        'fields': fields,
      }),
    );
    await flush();
  }

  @override
  Future<void> delete(String accountId, String groupId) async {
    await storage.delete(key: _key(accountId, groupId));
    await flush();
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    final keys = await storage.readAll();
    for (final key
        in keys.keys
            .where(
              (key) => key.startsWith('oweloop.unsent_expense.v1.$accountId.'),
            )
            .toList()) {
      await storage.delete(key: key);
    }
    await flush();
  }
}

final expenseDraftStoreProvider = Provider<ExpenseDraftStore>(
  (ref) => SecureExpenseDraftStore(const FlutterSecureStorage()),
);
