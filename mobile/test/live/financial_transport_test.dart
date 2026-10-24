// Explicitly configured local SDK integration, separate from ordinary unit runs.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oweloop/core/operations/client_operation_id.dart';
import 'package:oweloop/core/operations/financial_operations_providers.dart';
import 'package:oweloop/core/operations/pending_financial_operations.dart';

class _MemoryOperations implements FinancialOperationStore {
  List<PendingFinancialOperation> saved = [];
  @override
  Future<List<PendingFinancialOperation>> read(String id) async =>
      List.of(saved);
  @override
  Future<void> write(
    String id,
    List<PendingFinancialOperation> operations,
  ) async {
    saved = List.of(operations);
  }
}

class _LoseResponse implements FinancialOperationTransport {
  _LoseResponse(this.delegate);
  final FinancialOperationTransport delegate;
  @override
  Future<Map<String, dynamic>> submit(
    String type,
    Map<String, dynamic> payload,
    String id,
  ) async {
    await delegate.submit(type, payload, id);
    throw TimeoutException('Injected response loss');
  }

  @override
  Future<Map<String, dynamic>?> lookup(String id) => delegate.lookup(id);
  @override
  bool isDefinitiveRejection(Object error) =>
      delegate.isDefinitiveRejection(error);
}

void main() {
  final url = Platform.environment['SUPABASE_URL'];
  final key = Platform.environment['SUPABASE_ANON_KEY'];
  final configured = url != null && key != null;
  SupabaseClient? client;
  late SupabaseFinancialOperationTransport transport;
  late String groupId, memberId;
  setUp(() async {
    if (!configured) return;
    expect(
      ['127.0.0.1', 'localhost', '::1'],
      contains(Uri.parse(url).host),
      reason: 'Hosted endpoints are refused.',
    );
    HttpOverrides.global = null;
    client = SupabaseClient(
      url,
      key,
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
    final random = Random.secure();
    await client!.auth.signUp(
      email: 'sdk-${DateTime.now().microsecondsSinceEpoch}@example.com',
      password:
          'Local-${List.generate(40, (_) => random.nextInt(16).toRadixString(16)).join()}',
    );
    await client!.rpc(
      'complete_profile',
      params: {'p_display_name': 'SDK transport fixture'},
    );
    final group = await client!
        .rpc(
          'create_group',
          params: {
            'p_name': 'Disposable SDK transport',
            'p_currency_code': 'AUD',
          },
        )
        .single();
    groupId = group['id'] as String;
    memberId =
        (await client!.rpc(
                      'get_group_member_snapshot',
                      params: {'p_group_id': groupId},
                    )
                    as List)
                .single['id']
            as String;
    transport = SupabaseFinancialOperationTransport(client!);
  });
  tearDown(() async {
    await client?.dispose();
  });
  test(
    'missing reconciliation is null through the real Dart PostgREST adapter',
    () async {
      expect(
        await transport.lookup(ClientOperationId.generate().value),
        isNull,
      );
    },
    skip: !configured,
  );
  test(
    'real Dart SDK lost-response recovery confirms exactly one record',
    () async {
      final store = _MemoryOperations();
      final service = PendingFinancialOperations(
        store: store,
        transport: _LoseResponse(transport),
        currentAccountId: () => client!.auth.currentUser?.id,
      );
      final payload = {
        'p_group_id': groupId,
        'p_description': 'SDK response interruption',
        'p_total_amount_minor': 101,
        'p_occurred_at': DateTime.now().toUtc().toIso8601String(),
        'p_payers': [
          {'member_id': memberId, 'amount_minor': 101},
        ],
        'p_splits': [
          {'member_id': memberId, 'amount_minor': 101},
        ],
      };
      await expectLater(
        service.execute(type: 'expense', groupId: groupId, payload: payload),
        throwsA(isA<FinancialOperationException>()),
      );
      final restored = PendingFinancialOperations(
        store: store,
        transport: transport,
        currentAccountId: () => client!.auth.currentUser?.id,
      );
      expect(await restored.reconcile(store.saved.single.id), isTrue);
      expect(
        (await client!.from('expenses').select('id').eq('group_id', groupId))
            .length,
        1,
      );
      expect(store.saved.single.status, FinancialOperationStatus.confirmed);
    },
    skip: !configured,
  );
}
