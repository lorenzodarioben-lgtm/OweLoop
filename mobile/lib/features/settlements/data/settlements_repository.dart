import '../domain/settlement_models.dart';
import '../../../core/operations/history_page.dart';

abstract interface class PagedSettlementsRepository
    implements SettlementsRepository {
  Future<HistoryPage<SettlementRecord>> loadSettlementPage({
    required String groupId,
    required String currencyCode,
    HistoryCursor? before,
    SettlementHistoryFilter filter = const SettlementHistoryFilter(),
  });
}

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
