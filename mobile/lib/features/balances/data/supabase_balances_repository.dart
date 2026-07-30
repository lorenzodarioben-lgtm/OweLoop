import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/balance_models.dart';
import 'balances_repository.dart';

class SupabaseBalancesRepository implements BalancesRepository {
  SupabaseBalancesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<GroupBalance>> loadGroupBalances({
    required String groupId,
    required String currencyCode,
  }) async {
    final rows = await _client.rpc(
      'get_group_balances',
      params: <String, dynamic>{'p_group_id': groupId},
    );

    return GroupBalance.ordered(
      (rows as List).map(
        (row) => GroupBalance.fromMap(
          Map<String, dynamic>.from(row),
          currencyCode: currencyCode,
        ),
      ),
    );
  }
}

class BalancesRepositoryException implements Exception {
  const BalancesRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
