import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/operations/history_page.dart';
import '../../../core/operations/pending_financial_operations.dart';

import '../../expenses/domain/exact_money.dart';
import '../domain/settlement_models.dart';
import 'settlements_repository.dart';

class SupabaseSettlementsRepository implements PagedSettlementsRepository {
  SupabaseSettlementsRepository(this._client, {this.operations});

  final SupabaseClient _client;
  @override
  Future<HistoryPage<SettlementRecord>> loadSettlementPage({
    required String groupId,
    required String currencyCode,
    HistoryCursor? before,
  }) async {
    final rows = await _client.rpc(
      'get_settlement_page',
      params: {
        'p_group_id': groupId,
        'p_limit': 50,
        ...?before?.params('p_before_settled_at'),
      },
    );
    final maps = (rows as List)
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final visible = maps.take(50).toList();
    final last = visible.isEmpty ? null : visible.last;
    return HistoryPage(
      items: visible
          .map(
            (row) => SettlementRecord.fromMap(
              row,
              groupId: groupId,
              currencyCode: currencyCode,
            ),
          )
          .toList(),
      next: maps.length > 50 && last != null
          ? HistoryCursor(
              occurredAt: DateTime.parse(last['settled_at'] as String),
              createdAt: DateTime.parse(last['created_at'] as String),
              id: last['settlement_id'] as String,
            )
          : null,
    );
  }

  final PendingFinancialOperations? operations;

  @override
  Future<List<SettlementRecord>> loadGroupSettlements({
    required String groupId,
    required String currencyCode,
  }) async {
    final items = <SettlementRecord>[];
    HistoryCursor? cursor;
    do {
      final page = await loadSettlementPage(
        groupId: groupId,
        currencyCode: currencyCode,
        before: cursor,
      );
      items.addAll(page.items);
      cursor = page.next;
    } while (cursor != null);
    return items;
  }

  @override
  Future<SettlementRecord> recordSettlement(
    SettlementCreationInput input,
  ) async {
    final params = <String, dynamic>{
      'p_group_id': input.groupId,
      'p_paying_member_id': input.payingMemberId,
      'p_receiving_member_id': input.receivingMemberId,
      'p_amount_minor': input.amount.minorUnits,
      'p_settled_at': input.settledAt.toUtc().toIso8601String(),
    };
    final row = operations == null
        ? await _client
              .rpc(
                'record_settlement',
                params: {...params, 'p_operation_id': input.operationId},
              )
              .single()
        : await operations!.execute(
            requestedOperationId: input.operationId,
            type: 'settlement',
            groupId: input.groupId,
            payload: params,
          );

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
