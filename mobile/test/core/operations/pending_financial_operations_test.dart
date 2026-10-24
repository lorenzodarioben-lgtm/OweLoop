import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/core/operations/pending_financial_operations.dart';

class MemoryStore implements FinancialOperationStore {
  final Map<String, String> data = {};
  bool failWrite = false;
  @override
  Future<List<PendingFinancialOperation>> read(String accountId) async =>
      ((jsonDecode(data[accountId] ?? '[]')) as List)
          .map(
            (dynamic value) => PendingFinancialOperation.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList();
  @override
  Future<void> write(
    String accountId,
    List<PendingFinancialOperation> operations,
  ) async {
    if (failWrite) throw StateError('storage unavailable');
    data[accountId] = jsonEncode(
      operations.map((operation) => operation.toJson()).toList(),
    );
  }
}

class TestTransport implements FinancialOperationTransport {
  final List<String> ids = [];
  final Map<String, Map<String, dynamic>> committed = {};
  bool loseResponse = false;
  bool reject = false;
  Completer<void>? blocker;
  @override
  Future<Map<String, dynamic>> submit(
    String type,
    Map<String, dynamic> payload,
    String operationId,
  ) async {
    ids.add(operationId);
    if (blocker != null) await blocker!.future;
    if (reject) throw const FormatException('rejected');
    final result = committed.putIfAbsent(
      operationId,
      () => {
        'id': 'record-${committed.length}',
        'group_id': payload['p_group_id'],
        'operation_type': type,
      },
    );
    if (loseResponse) throw TimeoutException('response lost after commit');
    return result;
  }

  @override
  Future<Map<String, dynamic>?> lookup(String operationId) async =>
      committed[operationId];
  @override
  bool isDefinitiveRejection(Object error) => error is FormatException;
}

void main() {
  late MemoryStore store;
  late TestTransport transport;
  String? account;
  PendingFinancialOperations service() => PendingFinancialOperations(
    store: store,
    transport: transport,
    currentAccountId: () => account,
  );
  const payload = {
    'p_group_id': 'group',
    'p_description': 'Dinner',
    'p_total_amount_minor': 100,
  };
  setUp(() {
    store = MemoryStore();
    transport = TestTransport();
    account = 'account-a';
  });
  test(
    'lost response after commit survives restart and reconciles once',
    () async {
      transport.loseResponse = true;
      await expectLater(
        service().execute(type: 'expense', groupId: 'group', payload: payload),
        throwsA(isA<FinancialOperationException>()),
      );
      final restored = service();
      final pending = (await restored.load()).single;
      expect(pending.status, FinancialOperationStatus.unknown);
      expect(await restored.reconcile(pending.id), isTrue);
      expect(
        (await restored.load()).single.status,
        FinancialOperationStatus.confirmed,
      );
      expect(transport.committed, hasLength(1));
    },
  );
  test(
    'explicit retry uses original identity and cannot duplicate the commit',
    () async {
      transport.loseResponse = true;
      await expectLater(
        service().execute(type: 'expense', groupId: 'group', payload: payload),
        throwsA(isA<FinancialOperationException>()),
      );
      transport.loseResponse = false;
      final restarted = service();
      await restarted.retry((await restarted.load()).single.id);
      expect(transport.ids.toSet(), hasLength(1));
      expect(transport.committed, hasLength(1));
    },
  );
  test(
    'unknown outcome prevents modified request and remains account scoped',
    () async {
      transport.loseResponse = true;
      await expectLater(
        service().execute(type: 'expense', groupId: 'group', payload: payload),
        throwsA(isA<FinancialOperationException>()),
      );
      await expectLater(
        service().execute(
          type: 'expense',
          groupId: 'group',
          payload: {...payload, 'p_description': 'Different'},
        ),
        throwsA(isA<FinancialOperationException>()),
      );
      expect(transport.ids, hasLength(1));
      account = 'account-b';
      expect(await service().load(), isEmpty);
      account = 'account-a';
      expect(await service().load(), hasLength(1));
    },
  );
  test('failed local persistence never sends a financial request', () async {
    store.failWrite = true;
    await expectLater(
      service().execute(type: 'expense', groupId: 'group', payload: payload),
      throwsStateError,
    );
    expect(transport.ids, isEmpty);
  });
  test(
    'rapid submissions are guarded and pending is persisted before send',
    () async {
      transport.blocker = Completer<void>();
      final operations = service();
      final first = operations.execute(
        type: 'expense',
        groupId: 'group',
        payload: payload,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        (await store.read('account-a')).single.status,
        FinancialOperationStatus.pending,
      );
      await expectLater(
        operations.execute(type: 'expense', groupId: 'group', payload: payload),
        throwsA(isA<FinancialOperationException>()),
      );
      transport.blocker!.complete();
      await first;
      expect(transport.ids, hasLength(1));
    },
  );
  test('only an authoritative rejection permits a new operation', () async {
    transport.reject = true;
    await expectLater(
      service().execute(type: 'expense', groupId: 'group', payload: payload),
      throwsFormatException,
    );
    expect(
      (await service().load()).single.status,
      FinancialOperationStatus.rejected,
    );
    transport.reject = false;
    await service().execute(
      type: 'expense',
      groupId: 'group',
      payload: payload,
    );
    expect(transport.ids.toSet(), hasLength(2));
  });
  test(
    'empty lookup never turns an uncertain result into a rejection',
    () async {
      transport.blocker = Completer<void>();
      final operations = PendingFinancialOperations(
        store: store,
        transport: transport,
        currentAccountId: () => account,
        requestTimeout: const Duration(milliseconds: 5),
      );
      await expectLater(
        operations.execute(
          type: 'settlement',
          groupId: 'group',
          payload: payload,
        ),
        throwsA(isA<FinancialOperationException>()),
      );
      final pending = (await operations.load()).single;
      expect(await operations.reconcile(pending.id), isFalse);
      expect((await operations.load()).single.unresolved, isTrue);
      transport.blocker!.complete();
    },
  );
  test(
    'a confirmed form identity is replayed locally until navigation finishes',
    () async {
      final operations = service();
      await operations.execute(
        type: 'expense',
        groupId: 'group',
        payload: payload,
        requestedOperationId: 'same-form',
      );
      await operations.execute(
        type: 'expense',
        groupId: 'group',
        payload: payload,
        requestedOperationId: 'same-form',
      );
      expect(transport.ids, hasLength(1));
      await operations.execute(
        type: 'expense',
        groupId: 'group',
        payload: payload,
        requestedOperationId: 'new-form',
      );
      expect(transport.ids, hasLength(2));
    },
  );
}
