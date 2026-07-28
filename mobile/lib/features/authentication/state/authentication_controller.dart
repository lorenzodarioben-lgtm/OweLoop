import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../domain/auth_models.dart';
import '../errors/auth_error_mapper.dart';
import 'authentication_state.dart';

class AuthenticationController extends ChangeNotifier {
  AuthenticationController({
    required this.authRepository,
    required this.profileRepository,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;

  AuthenticationState _state = const AuthenticationState.loading();
  StreamSubscription<AuthSessionEvent>? _authSubscription;
  bool _hasStarted = false;
  bool _isDisposed = false;

  AuthenticationState get state => _state;

  Future<void> initialize() async {
    if (_hasStarted) {
      return;
    }

    _hasStarted = true;
    _authSubscription = authRepository.authEvents.listen(
      (event) => unawaited(_handleAuthEvent(event)),
    );

    try {
      final user = await authRepository.restoreSession();
      if (user == null) {
        _setState(const AuthenticationState.signedOut());
        return;
      }

      await _loadProfileFor(user);
    } catch (error) {
      _setState(
        AuthenticationState.signedOut(
          errorMessage: AuthErrorMapper.messageFor(error),
        ),
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    if (_state.isSubmitting) {
      return;
    }

    _setState(
      const AuthenticationState.signedOut().copyWith(isSubmitting: true),
    );

    try {
      final user = await authRepository.signIn(
        email: email,
        password: password,
      );
      await _loadProfileFor(user);
    } catch (error) {
      _setState(
        AuthenticationState.signedOut(
          errorMessage: AuthErrorMapper.messageFor(error),
        ),
      );
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    if (_state.isSubmitting) {
      return;
    }

    _setState(
      const AuthenticationState.signedOut().copyWith(isSubmitting: true),
    );

    try {
      final result = await authRepository.signUp(
        email: email,
        password: password,
      );

      if (result.disposition == SignUpDisposition.verificationRequired) {
        _setState(AuthenticationState.verificationPending(email: result.email));
        return;
      }

      final user = result.user;
      if (user == null) {
        throw StateError('The authenticated sign-up result has no user.');
      }

      await _loadProfileFor(user);
    } catch (error) {
      _setState(
        AuthenticationState.signedOut(
          errorMessage: AuthErrorMapper.messageFor(error),
        ),
      );
    }
  }

  Future<void> completeProfile({required String displayName}) async {
    if (_state.isSubmitting) {
      return;
    }

    final user = _state.user;
    if (user == null) {
      _setState(const AuthenticationState.signedOut());
      return;
    }

    _setState(
      AuthenticationState(
        status: AuthenticationStatus.profileSetup,
        user: user,
        profile: _state.profile,
        isSubmitting: true,
      ),
    );

    try {
      final profile = await profileRepository.completeProfile(
        displayName: displayName,
      );
      _setState(
        AuthenticationState(
          status: AuthenticationStatus.authenticated,
          user: user,
          profile: profile,
        ),
      );
    } catch (error) {
      _setState(
        AuthenticationState(
          status: AuthenticationStatus.profileSetup,
          user: user,
          profile: _state.profile,
          errorMessage: AuthErrorMapper.messageFor(error),
        ),
      );
    }
  }

  Future<void> signOut() async {
    if (_state.isSubmitting) {
      return;
    }

    final previousState = _state;
    _setState(previousState.copyWith(isSubmitting: true));

    try {
      await authRepository.signOut();
      _setState(const AuthenticationState.signedOut());
    } catch (error) {
      _setState(
        previousState.copyWith(
          errorMessage: AuthErrorMapper.messageFor(error),
          isSubmitting: false,
        ),
      );
    }
  }

  void dismissVerificationMessage() {
    _setState(const AuthenticationState.signedOut());
  }

  Future<void> _handleAuthEvent(AuthSessionEvent event) async {
    switch (event.type) {
      case AuthSessionEventType.signedOut:
        _setState(const AuthenticationState.signedOut());
      case AuthSessionEventType.signedIn:
      case AuthSessionEventType.tokenRefreshed:
      case AuthSessionEventType.userUpdated:
        final user = event.user;
        if (user != null) {
          await _loadProfileFor(user);
        }
    }
  }

  Future<void> _loadProfileFor(AuthenticatedUser user) async {
    _setState(
      AuthenticationState(status: AuthenticationStatus.loading, user: user),
    );

    try {
      final profile = await profileRepository.loadCurrentProfile();
      final status = profile?.hasCompletedOnboarding ?? false
          ? AuthenticationStatus.authenticated
          : AuthenticationStatus.profileSetup;

      _setState(
        AuthenticationState(status: status, user: user, profile: profile),
      );
    } catch (error) {
      _setState(
        AuthenticationState(
          status: AuthenticationStatus.profileSetup,
          user: user,
          errorMessage: AuthErrorMapper.messageFor(error),
        ),
      );
    }
  }

  void _setState(AuthenticationState state) {
    if (_isDisposed) {
      return;
    }

    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
