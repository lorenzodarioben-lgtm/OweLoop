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

/// Loopback TCP fault injection around the real Auth/PostgREST stack. The
/// after-commit case drains the upstream success before severing the socket.
class _WireFaultProxy {
  _WireFaultProxy(this.upstream);
  final Uri upstream;
  final HttpClient http = HttpClient();
  late HttpServer server;
  String fault = 'none';
  int forwardedPosts = 0;
  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        final body = await request.fold<List<int>>(
          [],
          (all, chunk) => all..addAll(chunk),
        );
        final financial = request.uri.path == '/rest/v1/rpc/create_expense';
        if (financial && fault == 'before') {
          (await request.response.detachSocket(writeHeaders: false)).destroy();
          return;
        }
        final target = await http.openUrl(
          request.method,
          upstream.replace(path: request.uri.path, query: request.uri.query),
        );
        request.headers.forEach((name, values) {
          if (![
            'host',
            'content-length',
            'transfer-encoding',
            'accept-encoding',
          ].contains(name)) {
            target.headers.set(name, values);
          }
        });
        target.add(body);
        final response = await target.close();
        final bytes = await response.fold<List<int>>(
          [],
          (all, chunk) => all..addAll(chunk),
        );
        if (financial) forwardedPosts++;
        if (financial && fault == 'after' && response.statusCode == 200) {
          (await request.response.detachSocket(writeHeaders: false)).destroy();
          return;
        }
        request.response.statusCode = response.statusCode;
        request.response.headers.contentType = ContentType.parse(
          response.headers.value('content-type') ?? 'application/json',
        );
        request.response.add(bytes);
        await request.response.close();
      } catch (_) {
        request.response.statusCode = 503;
        await request.response.close();
      }
    });
  }

  Future<void> close() async {
    http.close(force: true);
    await server.close(force: true);
  }
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
  for (final fault in ['before', 'after']) {
    test(
      'real TCP interruption $fault send preserves same-ID recovery',
      () async {
        final proxy = _WireFaultProxy(Uri.parse(url!));
        await proxy.start();
        addTearDown(proxy.close);
        final proxied = SupabaseClient(
          'http://127.0.0.1:${proxy.server.port}',
          key!,
          authOptions: const AuthClientOptions(
            autoRefreshToken: false,
            authFlowType: AuthFlowType.implicit,
          ),
        );
        addTearDown(proxied.dispose);
        await proxied.auth.setSession(
          client!.auth.currentSession!.refreshToken!,
        );
        proxy.fault = fault;
        final store = _MemoryOperations();
        final service = PendingFinancialOperations(
          store: store,
          transport: SupabaseFinancialOperationTransport(proxied),
          currentAccountId: () => proxied.auth.currentUser?.id,
          requestTimeout: const Duration(seconds: 10),
        );
        final id = ClientOperationId.generate().value;
        final payload = {
          'p_group_id': groupId,
          'p_description': 'TCP interruption fixture',
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
          service.execute(
            type: 'expense',
            groupId: groupId,
            payload: payload,
            requestedOperationId: id,
          ),
          throwsA(isA<FinancialOperationException>()),
        );
        expect(store.saved.single.id, id);
        expect(store.saved.single.unresolved, isTrue);
        expect(
          (await client!.from('expenses').select('id').eq('group_id', groupId))
              .length,
          fault == 'before' ? 0 : 1,
        );
        proxy.fault = 'none';
        final committed = await service.reconcile(id);
        expect(committed, fault == 'after');
        if (!committed) await service.retry(id);
        expect(await service.reconcile(id), isTrue);
        expect(store.saved.single.status, FinancialOperationStatus.confirmed);
        expect(store.saved.single.id, id);
        expect(store.saved.single.payload, payload);
        expect(
          (await client!.from('expenses').select('id').eq('group_id', groupId))
              .length,
          1,
        );
        expect(proxy.forwardedPosts, greaterThanOrEqualTo(1));
      },
      skip: !configured,
    );
  }
}
