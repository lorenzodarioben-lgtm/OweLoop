import 'package:flutter/foundation.dart';

import '../data/guest_claims_repository.dart';
import '../domain/guest_claim_models.dart';
import '../errors/guest_claims_error_mapper.dart';
import 'guest_claims_state.dart';

class GuestClaimInboxController extends ChangeNotifier {
  GuestClaimInboxController(this._repository);

  final GuestClaimsRepository _repository;
  GuestClaimInboxState _state = const GuestClaimInboxState.loading();
  bool _isDisposed = false;
  int _sessionGeneration = 0;

  GuestClaimInboxState get state => _state;

  Future<void> load() async {
    final sessionGeneration = _sessionGeneration;
    if (_state.status == GuestClaimInboxStatus.loading &&
        _state.claimRequests.isEmpty) {
      _setState(const GuestClaimInboxState.loading());
    } else {
      _setState(_state.copyWith(isRefreshing: true, clearErrorMessage: true));
    }
    try {
      final claimRequests = await _repository.loadPendingClaimRequests();
      if (sessionGeneration != _sessionGeneration) return;
      _setState(
        GuestClaimInboxState(
          status: GuestClaimInboxStatus.ready,
          claimRequests: claimRequests,
        ),
      );
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return;
      _setState(
        GuestClaimInboxState(
          status: GuestClaimInboxStatus.error,
          claimRequests: _state.claimRequests,
          errorMessage: GuestClaimsErrorMapper.messageFor(error),
        ),
      );
    }
  }

  Future<void> refresh() => load();

  Future<bool> accept(String claimRequestId) => _act(
    claimRequestId,
    () => _repository.acceptClaimRequest(claimRequestId),
  );

  Future<bool> decline(String claimRequestId) => _act(
    claimRequestId,
    () => _repository.declineClaimRequest(claimRequestId),
  );

  Future<bool> _act(
    String claimRequestId,
    Future<void> Function() operation,
  ) async {
    if (_state.pendingActionId != null) return false;
    final sessionGeneration = _sessionGeneration;
    _setState(
      _state.copyWith(pendingActionId: claimRequestId, clearErrorMessage: true),
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
          errorMessage: GuestClaimsErrorMapper.messageFor(error),
        ),
      );
      return false;
    }
  }

  void clear() {
    _sessionGeneration += 1;
    _setState(const GuestClaimInboxState.loading());
  }

  void _setState(GuestClaimInboxState state) {
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

class GroupGuestClaimsController extends ChangeNotifier {
  GroupGuestClaimsController({required this.groupId, required this.repository});

  final String groupId;
  final GuestClaimsRepository repository;
  GroupGuestClaimsState _state = const GroupGuestClaimsState.loading();
  bool _isDisposed = false;
  int _sessionGeneration = 0;

  GroupGuestClaimsState get state => _state;

  Future<void> load() async {
    final sessionGeneration = _sessionGeneration;
    if (_state.status == GroupGuestClaimsStatus.loading &&
        _state.claimRequests.isEmpty) {
      _setState(const GroupGuestClaimsState.loading());
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
      final claimRequests = await repository.loadGroupClaimRequests(groupId);
      if (sessionGeneration != _sessionGeneration) return;
      _setState(
        GroupGuestClaimsState(
          status: GroupGuestClaimsStatus.ready,
          claimRequests: claimRequests,
        ),
      );
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return;
      _setState(
        GroupGuestClaimsState(
          status: GroupGuestClaimsStatus.error,
          claimRequests: _state.claimRequests,
          errorMessage: GuestClaimsErrorMapper.messageFor(error),
        ),
      );
    }
  }

  Future<bool> create({
    required String guestMemberId,
    required GuestClaimInput input,
  }) async {
    if (_state.isBusy) return false;
    final sessionGeneration = _sessionGeneration;
    _setState(
      _state.copyWith(
        creatingGuestMemberId: guestMemberId,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );
    try {
      await repository.createClaimRequest(
        groupId: groupId,
        guestMemberId: guestMemberId,
        input: input,
      );
      if (sessionGeneration != _sessionGeneration) return false;
      final claimRequests = await repository.loadGroupClaimRequests(groupId);
      if (sessionGeneration != _sessionGeneration) return false;
      _setState(
        GroupGuestClaimsState(
          status: GroupGuestClaimsStatus.ready,
          claimRequests: claimRequests,
          successMessage:
              'If that email belongs to an eligible OweLoop account, they can review the claim in their inbox.',
        ),
      );
      return true;
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return false;
      _setState(
        _state.copyWith(
          clearCreatingGuestMemberId: true,
          errorMessage: GuestClaimsErrorMapper.messageFor(error),
        ),
      );
      return false;
    }
  }

  Future<bool> revoke(String claimRequestId) async {
    if (_state.isBusy) return false;
    final sessionGeneration = _sessionGeneration;
    _setState(
      _state.copyWith(
        revokingClaimRequestId: claimRequestId,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );
    try {
      await repository.revokeClaimRequest(claimRequestId);
      if (sessionGeneration != _sessionGeneration) return false;
      final claimRequests = await repository.loadGroupClaimRequests(groupId);
      if (sessionGeneration != _sessionGeneration) return false;
      _setState(
        GroupGuestClaimsState(
          status: GroupGuestClaimsStatus.ready,
          claimRequests: claimRequests,
        ),
      );
      return true;
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return false;
      _setState(
        _state.copyWith(
          clearRevokingClaimRequestId: true,
          errorMessage: GuestClaimsErrorMapper.messageFor(error),
        ),
      );
      return false;
    }
  }

  void clear() {
    _sessionGeneration += 1;
    _setState(const GroupGuestClaimsState.loading());
  }

  void _setState(GroupGuestClaimsState state) {
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
