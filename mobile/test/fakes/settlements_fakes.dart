import 'package:oweloop/features/expenses/domain/exact_money.dart';
import 'package:oweloop/features/settlements/data/settlements_repository.dart';
import 'package:oweloop/features/settlements/domain/settlement_models.dart';

class FakeSettlementsRepository implements SettlementsRepository {
  List<SettlementRecord> settlements = [];
  SettlementRecord? createdSettlement;
  Object? loadError;
  Object? recordError;
  Object? voidError;
  int loadCalls = 0;
  SettlementCreationInput? lastInput;

  @override
  Future<List<SettlementRecord>> loadGroupSettlements({
    required String groupId,
    required String currencyCode,
  }) async {
    loadCalls += 1;
    if (loadError != null) throw loadError!;
    return List<SettlementRecord>.from(settlements);
  }

  @override
  Future<SettlementRecord> recordSettlement(
    SettlementCreationInput input,
  ) async {
    lastInput = input;
    if (recordError != null) throw recordError!;
    return createdSettlement ?? testSettlement;
  }

  @override
  Future<SettlementRecord> voidSettlement({
    required String settlementId,
    required String groupId,
    required String currencyCode,
  }) async {
    if (voidError != null) throw voidError!;
    final index = settlements.indexWhere(
      (settlement) => settlement.id == settlementId,
    );
    if (index >= 0) {
      settlements[index] = SettlementRecord(
        id: settlements[index].id,
        groupId: settlements[index].groupId,
        payingMemberId: settlements[index].payingMemberId,
        payingMemberName: settlements[index].payingMemberName,
        receivingMemberId: settlements[index].receivingMemberId,
        receivingMemberName: settlements[index].receivingMemberName,
        amount: settlements[index].amount,
        settledAt: settlements[index].settledAt,
        isVoided: true,
        voidedAt: DateTime.utc(2026, 8, 1),
      );
      return settlements[index];
    }
    return testVoidedSettlement;
  }
}

final testSettlement = SettlementRecord(
  id: 'settlement-1',
  groupId: 'group-1',
  payingMemberId: 'member-a',
  payingMemberName: 'Taylor',
  receivingMemberId: 'member-b',
  receivingMemberName: 'Morgan',
  amount: const ExactMoney(currencyCode: 'AUD', minorUnits: 1250),
  settledAt: DateTime.utc(2026, 8, 1, 12),
  isVoided: false,
);

final testVoidedSettlement = SettlementRecord(
  id: testSettlement.id,
  groupId: testSettlement.groupId,
  payingMemberId: testSettlement.payingMemberId,
  payingMemberName: testSettlement.payingMemberName,
  receivingMemberId: testSettlement.receivingMemberId,
  receivingMemberName: testSettlement.receivingMemberName,
  amount: testSettlement.amount,
  settledAt: testSettlement.settledAt,
  isVoided: true,
  voidedAt: DateTime.utc(2026, 8, 2),
);
