import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/expenses/domain/expense_draft_review.dart';

void main() {
  test(
    'review removes inactive identities without redistributing their amounts',
    () {
      final review = ExpenseDraftReview(
        {
          'amount': '12.34',
          'category_key': 'groceries',
          'split_method': 'exact',
          'single_payer': 'removed',
          'payer_ids': ['removed'],
          'participant_ids': ['active', 'removed'],
          'split_values': {'active': '4.00', 'removed': '8.34'},
          'payer_amounts': {'removed': '12.34'},
          'operation_id': 'forbidden',
        },
        {'active'},
      );
      expect(review.fields['single_payer'], isNull);
      expect(review.fields['participant_ids'], ['active']);
      expect(review.fields['split_values'], {'active': '4.00'});
      expect(review.fields['payer_amounts'], isEmpty);
      expect(review.fields['amount'], '12.34');
      expect(review.fields['category_key'], 'groceries');
      expect(review.fields.containsKey('operation_id'), isFalse);
      expect(review.removedIds, {'removed'});
    },
  );
}
