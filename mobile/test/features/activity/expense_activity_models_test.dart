import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/activity/domain/expense_activity_models.dart';

void main() {
  test('maps safe known and unknown audit activity without raw JSON', () {
    final payer = ExpenseActivityEvent.fromMap(<String, dynamic>{
      'event_id': 'event-1',
      'event_type': 'payer_added',
      'occurred_at': '2026-08-03T12:00:00Z',
      'member_display_name': 'Morgan',
      'amount_minor': '250',
    }, currencyCode: 'USD');
    final unknown = ExpenseActivityEvent.fromMap(<String, dynamic>{
      'event_id': 'event-2',
      'event_type': 'future_event',
      'occurred_at': '2026-08-03T12:01:00Z',
    }, currencyCode: 'USD');

    expect(payer.title, 'Payer allocation recorded');
    expect(payer.detail, 'Morgan paid USD 2.50');
    expect(unknown.title, 'Activity recorded');
    expect(unknown.detail, isNull);
  });
}
