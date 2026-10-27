/// Review unposted configuration against current membership. This never creates
/// a financial identity, chooses a replacement payer or changes allocations.
class ExpenseDraftReview {
  ExpenseDraftReview(Map<String, dynamic> fields, Set<String> activeIds) {
    final selected = <String>{};
    List<String> ids(String key) =>
        (fields[key] as List? ?? []).cast<String>().where((id) {
          selected.add(id);
          return activeIds.contains(id);
        }).toList();
    final payer = fields['single_payer'] as String?;
    if (payer != null) selected.add(payer);
    final payers = ids('payer_ids');
    final participants = ids('participant_ids');
    Map<String, String> values(String key) => {
      for (final entry in (fields[key] as Map? ?? {}).entries)
        if (activeIds.contains(entry.key))
          entry.key as String: entry.value as String,
    };
    this.fields = {
      for (final key in [
        'description',
        'category_key',
        'amount',
        'occurred_on',
        'split_method',
        'multiple_payers',
      ])
        if (fields.containsKey(key)) key: fields[key],
      'single_payer': activeIds.contains(payer) ? payer : null,
      'payer_ids': payers,
      'participant_ids': participants,
      'payer_amounts': values('payer_amounts'),
      'split_values': values('split_values'),
    };
    removedIds = selected.difference(activeIds);
  }
  late final Map<String, dynamic> fields;
  late final Set<String> removedIds;
}
