import '../domain/group_models.dart';

abstract interface class GroupsRepository {
  Future<List<AppGroup>> loadCurrentUserGroups();

  Future<AppGroup> createGroup(GroupCreationInput input);

  Future<AppGroup?> loadAccessibleGroup(String groupId);

  Future<List<GroupMember>> loadGroupMembers(String groupId);

  Future<GroupMember> addGuestMember({
    required String groupId,
    required GuestCreationInput input,
  });

  Future<AppGroup> renameGroup({
    required String groupId,
    required GroupRenameInput input,
  });

  Future<AppGroup> archiveGroup(String groupId);

  Future<GroupMember> removeGroupMember({
    required String groupId,
    required String memberId,
  });

  Future<GroupMember> setGroupMemberRole({
    required String groupId,
    required String memberId,
    required GroupRole role,
  });

  Future<void> transferGroupOwnership({
    required String groupId,
    required String successorMemberId,
  });
}
