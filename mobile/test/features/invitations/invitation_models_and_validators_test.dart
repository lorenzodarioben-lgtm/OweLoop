import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/invitations/domain/invitation_models.dart';
import 'package:oweloop/features/invitations/validation/invitation_validators.dart';

void main() {
  test('maps recipient and inviter invitation RPC rows', () {
    final inboxInvitation = GroupInvitation.fromInboxMap(<String, dynamic>{
      'invitation_id': 'invitation-1',
      'group_id': 'group-1',
      'group_name': 'Weekend trip',
      'currency_code': 'AUD',
      'inviter_display_name': 'Taylor',
      'expires_at': '2026-09-01T00:00:00Z',
    });
    final sentInvitation = SentGroupInvitation.fromMap(<String, dynamic>{
      'invitation_id': 'invitation-2',
      'recipient_email': 'morgan@example.test',
      'created_at': '2026-08-15T00:00:00Z',
      'expires_at': '2026-08-29T00:00:00Z',
    });

    expect(inboxInvitation.groupName, 'Weekend trip');
    expect(sentInvitation.recipientEmail, 'morgan@example.test');
    expect(sentInvitation.expiresAt, DateTime.utc(2026, 8, 29));
  });

  test('normalizes an invitation email but validates input first', () {
    const input = GroupInvitationInput(email: ' Morgan@Example.Test ');

    expect(input.normalizedEmail, 'morgan@example.test');
    expect(InvitationValidators.email(''), 'Enter an email address.');
    expect(
      InvitationValidators.email('not-an-email'),
      'Enter a valid email address.',
    );
    expect(InvitationValidators.email('morgan@example.test'), isNull);
  });
}
