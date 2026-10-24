import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/core/operations/financial_operations_providers.dart';
import 'package:oweloop/core/operations/pending_financial_operations.dart';
import 'package:oweloop/core/operations/pending_operations_screen.dart';

class ScreenStore implements FinancialOperationStore {
  List<PendingFinancialOperation> records = [
    PendingFinancialOperation(
      id: '11111111-1111-4111-8111-111111111111',
      accountId: 'owner',
      type: 'expense',
      groupId: 'group',
      payload: {'p_description': 'Interrupted shared dinner'},
      status: FinancialOperationStatus.unknown,
      createdAt: DateTime.utc(2026),
    ),
  ];
  @override
  Future<List<PendingFinancialOperation>> read(String accountId) async =>
      List.of(records);
  @override
  Future<void> write(
    String accountId,
    List<PendingFinancialOperation> operations,
  ) async {
    records = List.of(operations);
  }
}

class ScreenTransport implements FinancialOperationTransport {
  int lookups = 0;
  @override
  Future<Map<String, dynamic>?> lookup(String operationId) async {
    lookups++;
    return {
      'operation_type': 'expense',
      'group_id': 'group',
      'expense_id': 'expense',
    };
  }

  @override
  bool isDefinitiveRejection(Object error) => false;
  @override
  Future<Map<String, dynamic>> submit(
    String type,
    Map<String, dynamic> payload,
    String operationId,
  ) async => {'id': 'expense'};
}

void main() {
  testWidgets(
    'phone-sized recovery remains readable and checks authoritative status',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final transport = ScreenTransport();
      final service = PendingFinancialOperations(
        store: ScreenStore(),
        transport: transport,
        currentAccountId: () => 'owner',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingFinancialOperationsProvider.overrideWithValue(service),
          ],
          child: const MaterialApp(home: PendingOperationsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final action = find.text('Check status');
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(transport.lookups, 1);
      expect(find.textContaining('server confirmed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
