import 'package:oweloop/features/groups/data/groups_repository.dart';
import 'package:oweloop/features/groups/domain/group_models.dart';

class FakeGroupsRepository implements GroupsRepository {
  FakeGroupsRepository({
    List<AppGroup>? groups,
    Map<String, AppGroup>? groupsById,
    Map<String, List<GroupMember>>? membersByGroupId,
    this.createdGroup,
    this.addedGuest,
  }) : groups = groups ?? [],
       groupsById = groupsById ?? {},
       membersByGroupId = membersByGroupId ?? {};

  List<AppGroup> groups;
  Map<String, AppGroup> groupsById;
  Map<String, List<GroupMember>> membersByGroupId;
  AppGroup? createdGroup;
  GroupMember? addedGuest;
  Object? loadGroupsError;
  Object? createGroupError;
  Object? loadGroupError;
  Object? loadMembersError;
  Object? addGuestError;
  Future<List<AppGroup>> Function()? loadGroupsHandler;
  Future<AppGroup> Function(GroupCreationInput input)? createGroupHandler;
  Future<GroupMember> Function({
    required String groupId,
    required GuestCreationInput input,
  })?
  addGuestHandler;
  int loadGroupsCalls = 0;
  int loadMembersCalls = 0;
  GroupCreationInput? lastGroupInput;
  GuestCreationInput? lastGuestInput;

  @override
  Future<List<AppGroup>> loadCurrentUserGroups() async {
    loadGroupsCalls += 1;
    if (loadGroupsHandler != null) {
      return loadGroupsHandler!();
    }
    if (loadGroupsError != null) {
      throw loadGroupsError!;
    }
    return List<AppGroup>.from(groups);
  }

  @override
  Future<AppGroup> createGroup(GroupCreationInput input) async {
    lastGroupInput = input;
    if (createGroupHandler != null) {
      return createGroupHandler!(input);
    }
    if (createGroupError != null) {
      throw createGroupError!;
    }
    final group =
        createdGroup ??
        (throw StateError('No created group was configured for this test.'));
    return group;
  }

  @override
  Future<AppGroup?> loadAccessibleGroup(String groupId) async {
    if (loadGroupError != null) {
      throw loadGroupError!;
    }
    return groupsById[groupId];
  }

  @override
  Future<List<GroupMember>> loadGroupMembers(String groupId) async {
    loadMembersCalls += 1;
    if (loadMembersError != null) {
      throw loadMembersError!;
    }
    return List<GroupMember>.from(membersByGroupId[groupId] ?? []);
  }

  @override
  Future<GroupMember> addGuestMember({
    required String groupId,
    required GuestCreationInput input,
  }) async {
    lastGuestInput = input;
    if (addGuestHandler != null) {
      return addGuestHandler!(groupId: groupId, input: input);
    }
    if (addGuestError != null) {
      throw addGuestError!;
    }
    return addedGuest ??
        (throw StateError('No added guest was configured for this test.'));
  }
}

const testGroup = AppGroup(
  id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  name: 'Weekend trip',
  currencyCode: 'AUD',
  currentUserRole: GroupRole.owner,
);

const secondTestGroup = AppGroup(
  id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  name: 'Household',
  currencyCode: 'USD',
  currentUserRole: GroupRole.member,
);

const testOwnerMember = GroupMember(
  id: 'owner-member',
  displayName: 'Taylor',
  role: GroupRole.owner,
  userId: '11111111-1111-1111-1111-111111111111',
);

const testGuestMember = GroupMember(
  id: 'guest-member',
  displayName: 'Morgan',
  role: GroupRole.member,
  userId: null,
);
