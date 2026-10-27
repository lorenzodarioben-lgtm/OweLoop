class HistoryCursor {
  const HistoryCursor({
    required this.occurredAt,
    required this.createdAt,
    required this.id,
  });
  final DateTime occurredAt, createdAt;
  final String id;
  Map<String, dynamic> params(String dateParameter) => {
    dateParameter: occurredAt.toUtc().toIso8601String(),
    'p_before_created_at': createdAt.toUtc().toIso8601String(),
    'p_before_id': id,
  };
}

class HistoryPage<T> {
  const HistoryPage({required this.items, this.next});
  final List<T> items;
  final HistoryCursor? next;
}

class ExpenseHistoryFilter {
  const ExpenseHistoryFilter({
    this.query = '',
    this.from,
    this.until,
    this.memberId,
    this.includeVoided = true,
    this.categoryKey,
  });
  final String query;
  final DateTime? from, until;
  final String? memberId;
  final String? categoryKey;
  final bool includeVoided;
  Map<String, dynamic> get params => {
    'p_query': query.trim(),
    'p_from': from?.toUtc().toIso8601String(),
    'p_until': until?.toUtc().toIso8601String(),
    'p_member_id': memberId,
    'p_include_voided': includeVoided,
    'p_category_key': categoryKey,
  };
}

class SettlementHistoryFilter {
  const SettlementHistoryFilter({
    this.from,
    this.until,
    this.payingMemberId,
    this.receivingMemberId,
    this.minMinor,
    this.maxMinor,
    this.state = 'all',
    this.oldestFirst = false,
  });
  final DateTime? from, until;
  final String? payingMemberId, receivingMemberId;
  final int? minMinor, maxMinor;
  final String state;
  final bool oldestFirst;
  Map<String, dynamic> get params => {
    'p_from': from?.toUtc().toIso8601String(),
    'p_until': until?.toUtc().toIso8601String(),
    'p_paying_member_id': payingMemberId,
    'p_receiving_member_id': receivingMemberId,
    'p_min_minor': minMinor,
    'p_max_minor': maxMinor,
    'p_state': state,
    'p_oldest_first': oldestFirst,
  };
}
