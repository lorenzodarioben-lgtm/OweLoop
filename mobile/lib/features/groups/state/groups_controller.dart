import 'package:flutter/foundation.dart';

import '../data/groups_repository.dart';
import '../domain/group_models.dart';
import '../errors/groups_error_mapper.dart';
import 'groups_state.dart';

class GroupsController extends ChangeNotifier {
  GroupsController(this._repository);

  final GroupsRepository _repository;
  GroupsState _state = const GroupsState.loading();
  bool _isDisposed = false;
  int _sessionGeneration = 0;

  GroupsState get state => _state;

  Future<void> load() async {
    final sessionGeneration = _sessionGeneration;
    if (_state.status == GroupsStatus.loading && _state.groups.isEmpty) {
      _setState(const GroupsState.loading());
    } else {
      _setState(_state.copyWith(isRefreshing: true, clearErrorMessage: true));
    }

    try {
      final groups = await _repository.loadCurrentUserGroups();
      if (sessionGeneration != _sessionGeneration) {
        return;
      }
      _setState(GroupsState(status: GroupsStatus.ready, groups: groups));
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) {
        return;
      }
      _setState(
        GroupsState(
          status: GroupsStatus.error,
          groups: _state.groups,
          errorMessage: GroupsErrorMapper.messageFor(error),
        ),
      );
    }
  }

  Future<void> refresh() => load();

  Future<AppGroup?> createGroup(GroupCreationInput input) async {
    if (_state.isCreating) {
      return null;
    }

    final sessionGeneration = _sessionGeneration;
    _setState(_state.copyWith(isCreating: true, clearErrorMessage: true));

    try {
      final group = await _repository.createGroup(input);
      final groups = await _repository.loadCurrentUserGroups();
      if (sessionGeneration != _sessionGeneration) {
        return null;
      }
      _setState(GroupsState(status: GroupsStatus.ready, groups: groups));
      return group;
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) {
        return null;
      }
      _setState(
        _state.copyWith(
          status: _state.groups.isEmpty
              ? GroupsStatus.error
              : GroupsStatus.ready,
          isCreating: false,
          errorMessage: GroupsErrorMapper.messageFor(error),
        ),
      );
      return null;
    }
  }

  void clear() {
    _sessionGeneration += 1;
    _setState(const GroupsState.loading());
  }

  void _setState(GroupsState state) {
    if (_isDisposed) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

class GroupDetailController extends ChangeNotifier {
  GroupDetailController({required this.groupId, required this.repository});

  final String groupId;
  final GroupsRepository repository;
  GroupDetailState _state = const GroupDetailState.loading();
  bool _isDisposed = false;

  GroupDetailState get state => _state;

  Future<void> load() async {
    _setState(
      GroupDetailState(
        status: GroupDetailStatus.loading,
        group: _state.group,
        members: _state.members,
      ),
    );

    try {
      final group = await repository.loadAccessibleGroup(groupId);
      if (group == null) {
        _setState(
          const GroupDetailState(status: GroupDetailStatus.unavailable),
        );
        return;
      }

      final members = await repository.loadGroupMembers(groupId);
      _setState(
        GroupDetailState(
          status: GroupDetailStatus.ready,
          group: group,
          members: members,
        ),
      );
    } catch (error) {
      _setState(
        GroupDetailState(
          status: GroupDetailStatus.error,
          group: _state.group,
          members: _state.members,
          errorMessage: GroupsErrorMapper.messageFor(error),
        ),
      );
    }
  }

  Future<bool> addGuest(GuestCreationInput input) async {
    if (_state.isAddingGuest) {
      return false;
    }

    _setState(_state.copyWith(isAddingGuest: true, clearErrorMessage: true));

    try {
      await repository.addGuestMember(groupId: groupId, input: input);
      final members = await repository.loadGroupMembers(groupId);
      _setState(
        GroupDetailState(
          status: GroupDetailStatus.ready,
          group: _state.group,
          members: members,
        ),
      );
      return true;
    } catch (error) {
      _setState(
        _state.copyWith(
          isAddingGuest: false,
          errorMessage: GroupsErrorMapper.messageFor(error),
        ),
      );
      return false;
    }
  }

  void clearError() {
    _setState(_state.copyWith(clearErrorMessage: true));
  }

  void _setState(GroupDetailState state) {
    if (_isDisposed) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
