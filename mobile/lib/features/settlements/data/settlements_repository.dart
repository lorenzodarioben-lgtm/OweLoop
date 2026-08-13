import '../domain/settlement_models.dart';

abstract interface class SettlementsRepository {
  Future<List<SettlementRecord>> loadGroupSettlements({
    required String groupId,
    required String currencyCode,
  });

  Future<SettlementRecord> recordSettlement(SettlementCreationInput input);

  Future<SettlementRecord> voidSettlement({
    required String settlementId,
    required String groupId,
    required String currencyCode,
  });
}

class SettlementsRepositoryException implements Exception {
  const SettlementsRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
