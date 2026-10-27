import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/core/operations/secure_storage_durability.dart';
import 'package:oweloop/core/operations/financial_operations_providers.dart';
import 'package:oweloop/core/operations/pending_financial_operations.dart';

class _Transport implements FinancialOperationTransport {
  final ids = <String>[];
  @override
  Future<Map<String, dynamic>> submit(
    String type,
    Map<String, dynamic> payload,
    String id,
  ) async {
    ids.add(id);
    return {'id': 'expense'};
  }

  @override
  Future<Map<String, dynamic>?> lookup(String id) async => null;
  @override
  bool isDefinitiveRejection(Object error) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('oweloop/secure_storage');
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'native fence carries no keys or payload and fails closed on false',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return false;
          });
      await expectLater(flushSecureStorage(android: true), throwsStateError);
      expect(calls.single.method, 'flush');
      expect(calls.single.arguments, isNull);
    },
  );
  test(
    'pending send waits for disk fence; failed retry cannot send cached intent',
    () async {
      var fail = true;
      final fence = Completer<void>();
      final entered = Completer<void>();
      final store = SecureFinancialOperationStore(
        const FlutterSecureStorage(),
        flush: () async {
          if (!entered.isCompleted) entered.complete();
          await fence.future;
          if (fail) throw StateError('disk failure');
        },
      );
      final transport = _Transport();
      final service = PendingFinancialOperations(
        store: store,
        transport: transport,
        currentAccountId: () => 'account',
      );
      final posting = service.execute(
        type: 'expense',
        groupId: 'group',
        payload: {'p_group_id': 'group'},
        requestedOperationId: 'original',
      );
      final rejected = expectLater(posting, throwsStateError);
      await entered.future;
      expect(transport.ids, isEmpty);
      fence.complete();
      await rejected;
      await expectLater(service.retry('original'), throwsStateError);
      expect(transport.ids, isEmpty);
      fail = false;
      await service.retry('original');
      expect(transport.ids, ['original']);
    },
  );
  test(
    'an unresponsive native fence ends with uncertainty rather than sending',
    () async {
      final response = Completer<bool>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => response.future);
      await expectLater(
        flushSecureStorage(
          android: true,
          timeout: const Duration(milliseconds: 5),
        ),
        throwsA(isA<TimeoutException>()),
      );
      response.complete(true);
    },
  );
}
