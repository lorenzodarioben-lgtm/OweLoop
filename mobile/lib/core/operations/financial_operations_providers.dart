import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pending_financial_operations.dart';

class SecureFinancialOperationStore implements FinancialOperationStore {
  SecureFinancialOperationStore(this.storage);
  final FlutterSecureStorage storage;
  String _key(String accountId) => 'oweloop.financial_operations.v1.$accountId';
  @override
  Future<List<PendingFinancialOperation>> read(String accountId) async {
    final encoded = await storage.read(key: _key(accountId));
    if (encoded == null) return [];
    return (jsonDecode(encoded) as List)
        .map(
          (dynamic json) => PendingFinancialOperation.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> write(
    String accountId,
    List<PendingFinancialOperation> operations,
  ) => storage.write(
    key: _key(accountId),
    value: jsonEncode(
      operations.map((operation) => operation.toJson()).toList(),
    ),
  );
}

class SupabaseFinancialOperationTransport
    implements FinancialOperationTransport {
  SupabaseFinancialOperationTransport(this.client);
  final SupabaseClient client;
  @override
  Future<Map<String, dynamic>> submit(
    String type,
    Map<String, dynamic> payload,
    String operationId,
  ) async {
    final function = switch (type) {
      'expense' => 'create_expense',
      'settlement' => 'record_settlement',
      _ => throw const FormatException('Unknown operation type.'),
    };
    final row = await client
        .rpc(function, params: {...payload, 'p_operation_id': operationId})
        .single();
    return Map<String, dynamic>.from(row);
  }

  @override
  Future<Map<String, dynamic>?> lookup(String operationId) async {
    final row = await client
        .rpc('get_financial_operation', params: {'p_operation_id': operationId})
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  @override
  bool isDefinitiveRejection(Object error) {
    if (error is! PostgrestException) return false;
    // The SDK also wraps truncated success bodies and proxy failures in this
    // type. Only explicit SQL transaction failures prove this attempt failed.
    final code = error.code ?? '';
    return code == 'P0001' ||
        code == '42501' ||
        code == '40001' ||
        code == '40P01' ||
        RegExp(r'^(22|23)[A-Z0-9]{3}$').hasMatch(code);
  }
}

final financialOperationStoreProvider = Provider<FinancialOperationStore>(
  (ref) => SecureFinancialOperationStore(const FlutterSecureStorage()),
);

final pendingFinancialOperationsProvider = Provider<PendingFinancialOperations>(
  (ref) {
    final client = Supabase.instance.client;
    return PendingFinancialOperations(
      store: ref.watch(financialOperationStoreProvider),
      transport: SupabaseFinancialOperationTransport(client),
      currentAccountId: () => client.auth.currentUser?.id,
    );
  },
);
