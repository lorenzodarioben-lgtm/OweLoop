import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/groups/domain/group_models.dart';
import 'package:oweloop/features/groups/errors/groups_error_mapper.dart';
import 'package:oweloop/features/groups/data/supabase_groups_repository.dart';
import 'package:oweloop/features/groups/validation/group_validators.dart';

void main() {
  group('GroupValidators', () {
    test('validates group names after trimming whitespace', () {
      expect(GroupValidators.groupName('  Weekend trip  '), isNull);
      expect(GroupValidators.groupName('   '), isNotNull);
      expect(GroupValidators.groupName('x' * 121), isNotNull);
    });

    test('only accepts the supported initial currencies', () {
      expect(GroupValidators.currency('AUD'), isNull);
      expect(GroupValidators.currency('USD'), isNull);
      expect(GroupValidators.currency('usd'), isNotNull);
      expect(GroupValidators.currency(null), isNotNull);
    });

    test('validates guest names after trimming whitespace', () {
      expect(GroupValidators.guestName('  Morgan  '), isNull);
      expect(GroupValidators.guestName('   '), isNotNull);
      expect(GroupValidators.guestName('x' * 81), isNotNull);
    });
  });

  group('Group models', () {
    test('parses group roles and membership maps safely', () {
      expect(GroupRole.fromDatabase('owner'), GroupRole.owner);
      expect(GroupRole.fromDatabase('admin'), GroupRole.admin);
      expect(GroupRole.fromDatabase('unknown'), GroupRole.member);

      final group = AppGroup.fromMembershipMap(<String, dynamic>{
        'id': 'group-id',
        'name': 'Trip',
        'currency_code': 'AUD',
        'created_at': '2026-07-29T00:00:00Z',
        'group_members': <Map<String, dynamic>>[
          <String, dynamic>{'role': 'admin'},
        ],
      });

      final guest = GroupMember.fromMap(<String, dynamic>{
        'id': 'guest-id',
        'display_name': 'Morgan',
        'role': 'member',
        'user_id': null,
      });

      expect(group.currentUserRole, GroupRole.admin);
      expect(group.createdAt, isNotNull);
      expect(guest.isGuest, isTrue);
    });
  });

  group('GroupsErrorMapper', () {
    test('maps backend failures to safe user-facing messages', () {
      expect(
        GroupsErrorMapper.messageFor(
          const GroupsRepositoryException('Guest display name cannot be blank'),
        ),
        'Enter a valid guest name.',
      );
      expect(
        GroupsErrorMapper.messageFor(
          const GroupsRepositoryException('permission denied for table groups'),
        ),
        'You do not have permission to do that.',
      );
      expect(
        GroupsErrorMapper.messageFor(Exception('internal SQL details')),
        'Something went wrong. Please try again.',
      );
    });
  });
}
