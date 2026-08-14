import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/group_models.dart';
import 'groups_repository.dart';

class SupabaseGroupsRepository implements GroupsRepository {
  SupabaseGroupsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AppGroup>> loadCurrentUserGroups() async {
    final userId = _currentUserId();
    final rows = await _client
        .from('groups')
        .select(
          'id, name, currency_code, created_at, archived_at, '
          'group_members!inner(role, user_id, removed_at)',
        )
        .eq('group_members.user_id', userId)
        .isFilter('group_members.removed_at', null)
        .isFilter('archived_at', null);

    final groups = (rows as List)
        .map(
          (row) => AppGroup.fromMembershipMap(Map<String, dynamic>.from(row)),
        )
        .toList();
    groups.sort((first, second) {
      final firstCreatedAt =
          first.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final secondCreatedAt =
          second.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return secondCreatedAt.compareTo(firstCreatedAt);
    });
    return groups;
  }

  @override
  Future<AppGroup> createGroup(GroupCreationInput input) async {
    _currentUserId();
    final row = await _client
        .from('groups')
        .insert(<String, dynamic>{
          'name': input.trimmedName,
          'currency_code': input.currencyCode,
        })
        .select('id, name, currency_code, created_at, archived_at')
        .single();

    return AppGroup.fromMap(
      Map<String, dynamic>.from(row),
      currentUserRole: GroupRole.owner,
    );
  }

  @override
  Future<AppGroup?> loadAccessibleGroup(String groupId) async {
    final userId = _currentUserId();
    final row = await _client
        .from('groups')
        .select(
          'id, name, currency_code, created_at, archived_at, '
          'group_members!inner(role, user_id, removed_at)',
        )
        .eq('id', groupId)
        .eq('group_members.user_id', userId)
        .isFilter('group_members.removed_at', null)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return AppGroup.fromMembershipMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<GroupMember>> loadGroupMembers(String groupId) async {
    final rows = await _client
        .from('group_members')
        .select('id, display_name, role, user_id, removed_at')
        .eq('group_id', groupId)
        .isFilter('removed_at', null)
        .order('created_at');

    return (rows as List)
        .map((row) => GroupMember.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<AppGroup> renameGroup({
    required String groupId,
    required GroupRenameInput input,
  }) async {
    final row = await _client
        .rpc(
          'rename_group',
          params: <String, dynamic>{
            'p_group_id': groupId,
            'p_name': input.trimmedName,
          },
        )
        .single();
    return AppGroup.fromMap(
      Map<String, dynamic>.from(row),
      currentUserRole: GroupRole.member,
    );
  }

  @override
  Future<AppGroup> archiveGroup(String groupId) async {
    final row = await _client
        .rpc('archive_group', params: <String, dynamic>{'p_group_id': groupId})
        .single();
    return AppGroup.fromMap(
      Map<String, dynamic>.from(row),
      currentUserRole: GroupRole.member,
    );
  }

  @override
  Future<GroupMember> removeGroupMember({
    required String groupId,
    required String memberId,
  }) async {
    final row = await _client
        .rpc(
          'remove_group_member',
          params: <String, dynamic>{
            'p_group_id': groupId,
            'p_member_id': memberId,
          },
        )
        .single();
    return GroupMember.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<GroupMember> setGroupMemberRole({
    required String groupId,
    required String memberId,
    required GroupRole role,
  }) async {
    final row = await _client
        .rpc(
          'set_group_member_role',
          params: <String, dynamic>{
            'p_group_id': groupId,
            'p_member_id': memberId,
            'p_role': role.name,
          },
        )
        .single();
    return GroupMember.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> transferGroupOwnership({
    required String groupId,
    required String successorMemberId,
  }) async {
    await _client.rpc(
      'transfer_group_ownership',
      params: <String, dynamic>{
        'p_group_id': groupId,
        'p_successor_member_id': successorMemberId,
      },
    );
  }

  @override
  Future<GroupMember> addGuestMember({
    required String groupId,
    required GuestCreationInput input,
  }) async {
    final row = await _client
        .rpc(
          'add_guest_member',
          params: <String, dynamic>{
            'p_group_id': groupId,
            'p_display_name': input.trimmedDisplayName,
          },
        )
        .single();

    return GroupMember.fromMap(Map<String, dynamic>.from(row));
  }

  String _currentUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const GroupsRepositoryException(
        'An authenticated user is required to access groups.',
      );
    }
    return userId;
  }
}

class GroupsRepositoryException implements Exception {
  const GroupsRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
