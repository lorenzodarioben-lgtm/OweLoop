import 'package:supabase_flutter/supabase_flutter.dart';

import '../../expenses/domain/exact_money.dart';
import '../domain/settlement_models.dart';
import 'settlements_repository.dart';

class SupabaseSettlementsRepository implements SettlementsRepository {
  SupabaseSettlementsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SettlementRecord>> loadGroupSettlements({
    required String groupId,
    required String currencyCode,
  }) async {
    final rows = await _client.rpc(
      'get_group_settlements',
      params: <String, dynamic>{'p_group_id': groupId},
    );

    return (rows as List)
        .map(
          (row) => SettlementRecord.fromMap(
            Map<String, dynamic>.from(row),
            groupId: groupId,
            currencyCode: currencyCode,
          ),
        )
        .toList();
  }

  @override
  Future<SettlementRecord> recordSettlement(
    SettlementCreationInput input,
  ) async {
    final row = await _client
        .rpc(
          'record_settlement',
          params: <String, dynamic>{
            'p_group_id': input.groupId,
            'p_paying_member_id': input.payingMemberId,
            'p_receiving_member_id': input.receivingMemberId,
            'p_amount_minor': input.amount.minorUnits,
            'p_settled_at': input.settledAt.toUtc().toIso8601String(),
            'p_operation_id': input.operationId,
          },
        )
        .single();

    final stored = Map<String, dynamic>.from(row);
    return SettlementRecord(
      id: stored['id'] as String,
      groupId: input.groupId,
      payingMemberId: stored['paying_member_id'] as String,
      payingMemberName: 'Member',
      receivingMemberId: stored['receiving_member_id'] as String,
      receivingMemberName: 'Member',
      amount: input.amount,
      settledAt: DateTime.parse(stored['settled_at'] as String),
      isVoided: false,
    );
  }

  @override
  Future<SettlementRecord> voidSettlement({
    required String settlementId,
    required String groupId,
    required String currencyCode,
  }) async {
    final row = await _client
        .rpc(
          'void_settlement',
          params: <String, dynamic>{'p_settlement_id': settlementId},
        )
        .single();
    final stored = Map<String, dynamic>.from(row);
    return SettlementRecord(
      id: stored['id'] as String,
      groupId: groupId,
      payingMemberId: stored['paying_member_id'] as String,
      payingMemberName: 'Member',
      receivingMemberId: stored['receiving_member_id'] as String,
      receivingMemberName: 'Member',
      amount: ExactMoney(
        currencyCode: currencyCode,
        minorUnits: stored['amount_minor'] as int,
      ),
      settledAt: DateTime.parse(stored['settled_at'] as String),
      isVoided: true,
      voidedAt: DateTime.parse(stored['voided_at'] as String),
    );
  }
}
