import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/expenses/domain/exact_money.dart';
import 'package:oweloop/features/settlements/data/settlements_repository.dart';
import 'package:oweloop/features/settlements/domain/settlement_models.dart';
import 'package:oweloop/features/settlements/state/settlements_controller.dart';
import 'package:oweloop/features/settlements/state/settlements_state.dart';

import '../../fakes/settlements_fakes.dart';

void main() {
  test('loads, records, and voids settlement history', () async {
    final repository = FakeSettlementsRepository()
      ..settlements = [testSettlement];
    final history = SettlementHistoryController(
      groupId: 'group-1',
      currencyCode: 'AUD',
      repository: repository,
    );
    final creation = SettlementCreationController(repository);

    await history.load();
    expect(history.state.status, SettlementHistoryStatus.ready);
    expect(history.state.settlements, [testSettlement]);

    final created = await creation.record(
      SettlementCreationInput(
        groupId: 'group-1',
        payingMemberId: 'member-a',
        receivingMemberId: 'member-b',
        amount: const ExactMoney(currencyCode: 'AUD', minorUnits: 1250),
        settledAt: DateTime.utc(2026, 8, 1, 12),
        operationId: '00000000-0000-4000-8000-000000000001',
      ),
    );
    expect(created, testSettlement);
    expect(repository.lastInput?.amount.minorUnits, 1250);

    expect(await history.voidSettlement(testSettlement.id), isTrue);
    expect(history.state.settlements.single.isVoided, isTrue);
  });

  test('maps settlement failures and clears private state', () async {
    final repository = FakeSettlementsRepository()
      ..recordError = const SettlementsRepositoryException(
        'Settlement amount must be greater than zero',
      );
    final controller = SettlementCreationController(repository);

    final result = await controller.record(
      SettlementCreationInput(
        groupId: 'group-1',
        payingMemberId: 'member-a',
        receivingMemberId: 'member-b',
        amount: const ExactMoney(currencyCode: 'AUD', minorUnits: 0),
        settledAt: DateTime.utc(2026, 8, 1),
        operationId: '00000000-0000-4000-8000-000000000002',
      ),
    );

    expect(result, isNull);
    expect(controller.state.errorMessage, 'Enter a valid positive amount.');
    controller.clear();
    expect(controller.state.errorMessage, isNull);
  });
}
