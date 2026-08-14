import 'package:flutter/foundation.dart';

import '../data/invitations_repository.dart';
import '../domain/invitation_models.dart';
import '../errors/invitations_error_mapper.dart';
import 'invitations_state.dart';

class InvitationInboxController extends ChangeNotifier {
  InvitationInboxController(this._repository);

  final InvitationsRepository _repository;
  InvitationInboxState _state = const InvitationInboxState.loading();
  bool _isDisposed = false;
  int _sessionGeneration = 0;

  InvitationInboxState get state => _state;

  Future<void> load() async {
    final sessionGeneration = _sessionGeneration;
    if (_state.status == InvitationInboxStatus.loading &&
        _state.invitations.isEmpty) {
      _setState(const InvitationInboxState.loading());
    } else {
      _setState(_state.copyWith(isRefreshing: true, clearErrorMessage: true));
    }
    try {
      final invitations = await _repository.loadPendingInvitations();
      if (sessionGeneration != _sessionGeneration) return;
      _setState(
        InvitationInboxState(
          status: InvitationInboxStatus.ready,
          invitations: invitations,
        ),
      );
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return;
      _setState(
        InvitationInboxState(
          status: InvitationInboxStatus.error,
          invitations: _state.invitations,
          errorMessage: InvitationsErrorMapper.messageFor(error),
        ),
      );
    }
  }

  Future<void> refresh() => load();

  Future<bool> accept(String invitationId) =>
      _act(invitationId, () => _repository.acceptInvitation(invitationId));

  Future<bool> decline(String invitationId) =>
      _act(invitationId, () => _repository.declineInvitation(invitationId));

  Future<bool> _act(
    String invitationId,
    Future<void> Function() operation,
  ) async {
    if (_state.pendingActionId != null) return false;
    final sessionGeneration = _sessionGeneration;
    _setState(
      _state.copyWith(pendingActionId: invitationId, clearErrorMessage: true),
    );
    try {
      await operation();
      if (sessionGeneration != _sessionGeneration) return false;
      await load();
      return true;
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return false;
      _setState(
        _state.copyWith(
          clearPendingActionId: true,
          errorMessage: InvitationsErrorMapper.messageFor(error),
        ),
      );
      return false;
    }
  }

  void clear() {
    _sessionGeneration += 1;
    _setState(const InvitationInboxState.loading());
  }

  void _setState(InvitationInboxState state) {
    if (_isDisposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

class GroupInvitationsController extends ChangeNotifier {
  GroupInvitationsController({required this.groupId, required this.repository});

  final String groupId;
  final InvitationsRepository repository;
  GroupInvitationsState _state = const GroupInvitationsState.loading();
  bool _isDisposed = false;
  int _sessionGeneration = 0;

  GroupInvitationsState get state => _state;

  Future<void> load() async {
    final sessionGeneration = _sessionGeneration;
    if (_state.status == GroupInvitationsStatus.loading &&
        _state.invitations.isEmpty) {
      _setState(const GroupInvitationsState.loading());
    } else {
      _setState(
        _state.copyWith(
          isRefreshing: true,
          clearErrorMessage: true,
          clearSuccessMessage: true,
        ),
      );
    }
    try {
      final invitations = await repository.loadGroupInvitations(groupId);
      if (sessionGeneration != _sessionGeneration) return;
      _setState(
        GroupInvitationsState(
          status: GroupInvitationsStatus.ready,
          invitations: invitations,
        ),
      );
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return;
      _setState(
        GroupInvitationsState(
          status: GroupInvitationsStatus.error,
          invitations: _state.invitations,
          errorMessage: InvitationsErrorMapper.messageFor(error),
        ),
      );
    }
  }

  Future<bool> create(GroupInvitationInput input) async {
    if (_state.isCreating || _state.revokingInvitationId != null) return false;
    final sessionGeneration = _sessionGeneration;
    _setState(
      _state.copyWith(
        isCreating: true,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );
    try {
      await repository.createInvitation(groupId: groupId, input: input);
      if (sessionGeneration != _sessionGeneration) return false;
      final invitations = await repository.loadGroupInvitations(groupId);
      if (sessionGeneration != _sessionGeneration) return false;
      _setState(
        GroupInvitationsState(
          status: GroupInvitationsStatus.ready,
          invitations: invitations,
          successMessage:
              'If that email belongs to an eligible OweLoop account, an invitation is ready in their inbox.',
        ),
      );
      return true;
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return false;
      _setState(
        _state.copyWith(
          isCreating: false,
          errorMessage: InvitationsErrorMapper.messageFor(error),
        ),
      );
      return false;
    }
  }

  Future<bool> revoke(String invitationId) async {
    if (_state.isCreating || _state.revokingInvitationId != null) return false;
    final sessionGeneration = _sessionGeneration;
    _setState(
      _state.copyWith(
        revokingInvitationId: invitationId,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );
    try {
      await repository.revokeInvitation(invitationId);
      if (sessionGeneration != _sessionGeneration) return false;
      final invitations = await repository.loadGroupInvitations(groupId);
      if (sessionGeneration != _sessionGeneration) return false;
      _setState(
        GroupInvitationsState(
          status: GroupInvitationsStatus.ready,
          invitations: invitations,
        ),
      );
      return true;
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return false;
      _setState(
        _state.copyWith(
          clearRevokingInvitationId: true,
          errorMessage: InvitationsErrorMapper.messageFor(error),
        ),
      );
      return false;
    }
  }

  void clear() {
    _sessionGeneration += 1;
    _setState(const GroupInvitationsState.loading());
  }

  void _setState(GroupInvitationsState state) {
    if (_isDisposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
