import '../domain/balance_models.dart';

abstract interface class BalancesRepository {
  Future<List<GroupBalance>> loadGroupBalances({
    required String groupId,
    required String currencyCode,
  });
}
