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
}
