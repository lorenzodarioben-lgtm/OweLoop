import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/groups/data/supabase_groups_repository.dart';
import 'package:oweloop/features/groups/domain/group_models.dart';
import 'package:oweloop/features/groups/state/groups_controller.dart';
import 'package:oweloop/features/groups/state/groups_state.dart';

import '../../fakes/groups_fakes.dart';

void main() {
  late FakeGroupsRepository repository;

  setUp(() {
    repository = FakeGroupsRepository();
  });

  test('loads an empty group list', () async {
    final controller = GroupsController(repository);

    await controller.load();

    expect(controller.state.status, GroupsStatus.ready);
    expect(controller.state.groups, isEmpty);
  });

  test('loads multiple groups', () async {
    repository.groups = const [testGroup, secondTestGroup];
    final controller = GroupsController(repository);

    await controller.load();

    expect(controller.state.groups, hasLength(2));
    expect(controller.state.groups.first.name, 'Weekend trip');
  });

  test('creates a group and refreshes the list', () async {
    repository.createdGroup = testGroup;
    repository.groups = const [testGroup];
    final controller = GroupsController(repository);

    final created = await controller.createGroup(
      const GroupCreationInput(name: ' Weekend trip ', currencyCode: 'AUD'),
    );

    expect(created, testGroup);
    expect(repository.lastGroupInput?.trimmedName, 'Weekend trip');
    expect(repository.loadGroupsCalls, 1);
    expect(controller.state.groups, const [testGroup]);
  });

  test('surfaces a safe group creation error', () async {
    repository.createGroupError = const GroupsRepositoryException(
      'Group name cannot be blank',
    );
    final controller = GroupsController(repository);

    final created = await controller.createGroup(
      const GroupCreationInput(name: 'Trip', currencyCode: 'AUD'),
    );

    expect(created, isNull);
    expect(controller.state.errorMessage, 'Enter a valid group name.');
  });

  test('retries a failed group list load', () async {
    repository.loadGroupsError = const GroupsRepositoryException(
      'network error',
    );
    final controller = GroupsController(repository);

    await controller.load();
    expect(controller.state.status, GroupsStatus.error);

    repository.loadGroupsError = null;
    repository.groups = const [testGroup];
    await controller.refresh();

    expect(controller.state.status, GroupsStatus.ready);
    expect(controller.state.groups, const [testGroup]);
  });

  test('clears groups after a session ends', () async {
    repository.groups = const [testGroup];
    final controller = GroupsController(repository);
    await controller.load();

    controller.clear();

    expect(controller.state.status, GroupsStatus.loading);
    expect(controller.state.groups, isEmpty);
  });

  test('does not restore stale groups after a session ends', () async {
    final loadCompleter = Completer<List<AppGroup>>();
    repository.loadGroupsHandler = () => loadCompleter.future;
    final controller = GroupsController(repository);

    final pendingLoad = controller.load();
    controller.clear();
    loadCompleter.complete(const [testGroup]);
    await pendingLoad;

    expect(controller.state.status, GroupsStatus.loading);
    expect(controller.state.groups, isEmpty);
  });

  test('loads accessible group details and members', () async {
    repository.groupsById[testGroup.id] = testGroup;
    repository.membersByGroupId[testGroup.id] = const [
      testOwnerMember,
      testGuestMember,
    ];
    final controller = GroupDetailController(
      groupId: testGroup.id,
      repository: repository,
    );

    await controller.load();

    expect(controller.state.status, GroupDetailStatus.ready);
    expect(controller.state.members, hasLength(2));
    expect(controller.state.members.last.isGuest, isTrue);
  });

  test('keeps an inaccessible group unavailable', () async {
    final controller = GroupDetailController(
      groupId: 'unavailable-group',
      repository: repository,
    );

    await controller.load();

    expect(controller.state.status, GroupDetailStatus.unavailable);
  });

  test('adds a guest and refreshes the member list', () async {
    repository.groupsById[testGroup.id] = testGroup;
    repository.membersByGroupId[testGroup.id] = const [
      testOwnerMember,
      testGuestMember,
    ];
    repository.addedGuest = testGuestMember;
    final controller = GroupDetailController(
      groupId: testGroup.id,
      repository: repository,
    );
    await controller.load();

    final added = await controller.addGuest(
      const GuestCreationInput(displayName: ' Morgan '),
    );

    expect(added, isTrue);
    expect(repository.lastGuestInput?.trimmedDisplayName, 'Morgan');
    expect(repository.loadMembersCalls, 2);
    expect(controller.state.members.last.displayName, 'Morgan');
  });

  test('keeps details visible when guest creation fails', () async {
    repository.groupsById[testGroup.id] = testGroup;
    repository.membersByGroupId[testGroup.id] = const [testOwnerMember];
    repository.addGuestError = const GroupsRepositoryException('network error');
    final controller = GroupDetailController(
      groupId: testGroup.id,
      repository: repository,
    );
    await controller.load();

    final added = await controller.addGuest(
      const GuestCreationInput(displayName: 'Morgan'),
    );

    expect(added, isFalse);
    expect(controller.state.status, GroupDetailStatus.ready);
    expect(controller.state.members, const [testOwnerMember]);
    expect(
      controller.state.errorMessage,
      'We could not reach OweLoop. Check your connection and try again.',
    );
  });
}
