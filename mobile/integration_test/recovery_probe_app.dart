// Standalone DEBUG test target. Never the release entry point. The host harness
// force-stops this real app at explicit barriers and resumes the same install.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oweloop/core/operations/client_operation_id.dart';
import 'package:oweloop/core/operations/financial_operations_providers.dart';
import 'package:oweloop/core/operations/pending_financial_operations.dart';

const _url = String.fromEnvironment('OWELOOP_TEST_SUPABASE_URL');
const _key = String.fromEnvironment('OWELOOP_TEST_ANON_KEY');
void marker(String value) => debugPrint('OWELOOP_PROBE:$value');
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('OweLoop local recovery probe'))),
    ),
  );
  try {
    if (![
          '127.0.0.1',
          'localhost',
          '10.0.2.2',
          '::1',
        ].contains(Uri.parse(_url).host) ||
        _key.isEmpty) {
      throw StateError('Local configuration required');
    }
    await Supabase.initialize(url: _url, publishableKey: _key);
    final client = Supabase.instance.client;
    final support = await getApplicationSupportDirectory();
    final phase = (await File(
      '${support.path}/oweloop-probe-phase',
    ).readAsString()).trim();
    final resume = phase.startsWith('resume-');
    final store = SecureFinancialOperationStore(const FlutterSecureStorage());
    final transport = SupabaseFinancialOperationTransport(client);
    if (!resume) {
      await client.auth.signOut();
      final random = Random.secure();
      final suffix = DateTime.now().microsecondsSinceEpoch;
      await client.auth.signUp(
        email: 'probe-$suffix@example.com',
        password:
            'Local-${List.generate(40, (_) => random.nextInt(16).toRadixString(16)).join()}',
      );
      await client.rpc(
        'complete_profile',
        params: {'p_display_name': 'Recovery probe'},
      );
      final group = Map<String, dynamic>.from(
        await client
            .rpc(
              'create_group',
              params: {
                'p_name': 'Disposable recovery probe',
                'p_currency_code': 'AUD',
              },
            )
            .single(),
      );
      final members = await client.rpc(
        'get_group_member_snapshot',
        params: {'p_group_id': group['id']},
      );
      final member = (members as List).single['id'];
      final service = PendingFinancialOperations(
        store: store,
        transport: _BarrierTransport(transport, phase),
        currentAccountId: () => client.auth.currentUser?.id,
      );
      await service.execute(
        type: 'expense',
        groupId: group['id'] as String,
        requestedOperationId: ClientOperationId.generate().value,
        payload: {
          'p_group_id': group['id'],
          'p_description': 'Process termination probe',
          'p_total_amount_minor': 101,
          'p_occurred_at': DateTime.now().toUtc().toIso8601String(),
          'p_payers': [
            {'member_id': member, 'amount_minor': 101},
          ],
          'p_splits': [
            {'member_id': member, 'amount_minor': 101},
          ],
        },
      );
      throw StateError('Barrier returned unexpectedly');
    }
    final service = PendingFinancialOperations(
      store: store,
      transport: transport,
      currentAccountId: () => client.auth.currentUser?.id,
    );
    final saved = (await service.load()).single;
    if (!saved.unresolved) {
      throw StateError('Pending request did not survive termination');
    }
    final committed = await service.reconcile(saved.id);
    if (phase == 'resume-before' && committed) {
      throw StateError('Before-send barrier wrote to server');
    }
    if (phase == 'resume-after' && !committed) {
      throw StateError('Committed result was lost');
    }
    if (!committed) await service.retry(saved.id);
    if (!(await service.reconcile(saved.id))) {
      throw StateError('Same-ID recovery failed');
    }
    final records = await client
        .from('expenses')
        .select('id,total_amount_minor')
        .eq('group_id', saved.groupId);
    if (records.length != 1 || records.single['total_amount_minor'] != 101) {
      throw StateError('Recovery duplicated or altered the expense');
    }
    if ((await service.load()).single.status !=
        FinancialOperationStatus.confirmed) {
      throw StateError('Confirmation was not persisted');
    }
    marker('PASS:$phase');
  } catch (error) {
    marker('FAIL:${error.runtimeType}');
  }
}

class _BarrierTransport implements FinancialOperationTransport {
  _BarrierTransport(this.delegate, this.phase);
  final SupabaseFinancialOperationTransport delegate;
  final String phase;
  @override
  Future<Map<String, dynamic>> submit(
    String type,
    Map<String, dynamic> payload,
    String operationId,
  ) async {
    if (phase == 'before') {
      marker('WAIT:before');
      return Completer<Map<String, dynamic>>().future;
    }
    await delegate.submit(type, payload, operationId);
    marker('WAIT:after');
    return Completer<Map<String, dynamic>>().future;
  }

  @override
  Future<Map<String, dynamic>?> lookup(String id) => delegate.lookup(id);
  @override
  bool isDefinitiveRejection(Object error) =>
      delegate.isDefinitiveRejection(error);
}
