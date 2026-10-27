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
  int _generation = 0;

  bool _current(int generation) => !_isDisposed && generation == _generation;

  AuthenticationState get state => _state;

  Future<void> initialize() async {
    if (_hasStarted) {
      return;
    }

    _hasStarted = true;
    final generation = _generation;
    _authSubscription = authRepository.authEvents.listen(
      (event) => unawaited(_handleAuthEvent(event)),
      onError: (Object error, StackTrace stackTrace) {
        _generation += 1;
        _setState(
          AuthenticationState.signedOut(
            errorMessage: AuthErrorMapper.messageFor(error),
          ),
        );
      },
    );

    try {
      final user = await authRepository.restoreSession();
      if (!_current(generation)) return;
      if (user == null) {
        _setState(const AuthenticationState.signedOut());
        return;
      }
      if (_state.status == AuthenticationStatus.passwordRecovery) {
        return;
      }

      await _loadProfileFor(user);
    } catch (error) {
      if (!_current(generation)) return;
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

    final generation = ++_generation;
    _setState(
      const AuthenticationState.signedOut().copyWith(isSubmitting: true),
    );

    try {
      final user = await authRepository.signIn(
        email: email,
        password: password,
      );
      if (!_current(generation)) return;
      await _loadProfileFor(user);
    } catch (error) {
      if (!_current(generation)) return;
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

    final generation = ++_generation;
    _setState(
      const AuthenticationState.signedOut().copyWith(isSubmitting: true),
    );

    try {
      final result = await authRepository.signUp(
        email: email,
        password: password,
      );
      if (!_current(generation)) return;

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
      if (!_current(generation)) return;
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

    final generation = _generation;
    final previousStatus = _state.status;
    _setState(
      AuthenticationState(
        status: previousStatus,
        user: user,
        profile: _state.profile,
        isSubmitting: true,
      ),
    );

    try {
      final profile = await profileRepository.completeProfile(
        displayName: displayName,
      );
      if (!_current(generation)) return;
      _setState(
        AuthenticationState(
          status: AuthenticationStatus.authenticated,
          user: user,
          profile: profile,
        ),
      );
    } catch (error) {
      if (!_current(generation)) return;
      _setState(
        AuthenticationState(
          status: previousStatus,
          user: user,
          profile: _state.profile,
          errorMessage: AuthErrorMapper.messageFor(error),
        ),
      );
    }
  }

  Future<void> resendVerification() async {
    if (_state.isSubmitting ||
        _state.status != AuthenticationStatus.verificationPending) {
      return;
    }
    final email = _state.pendingEmail;
    if (email == null || email.isEmpty) {
      _setState(const AuthenticationState.signedOut());
      return;
    }

    final generation = _generation;
    _setState(_state.copyWith(isSubmitting: true, clearErrorMessage: true));
    try {
      await authRepository.resendVerification(email: email);
      if (!_current(generation)) return;
      _setState(
        _state.copyWith(
          isSubmitting: false,
          noticeMessage:
              'If confirmation is still needed, a new verification email will arrive shortly.',
          clearErrorMessage: true,
        ),
      );
    } catch (error) {
      if (!_current(generation)) return;
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: AuthErrorMapper.messageFor(error),
          clearNoticeMessage: true,
        ),
      );
    }
  }

  Future<void> requestPasswordRecovery({required String email}) async {
    if (_state.isSubmitting) {
      return;
    }

    final generation = ++_generation;
    _setState(
      const AuthenticationState.signedOut().copyWith(isSubmitting: true),
    );
    try {
      await authRepository.requestPasswordRecovery(email: email);
      if (!_current(generation)) return;
      _setState(_passwordRecoveryRequestSentState);
    } catch (error) {
      if (!_current(generation)) return;
      final message = AuthErrorMapper.messageFor(error);
      if (message == _networkErrorMessage) {
        _setState(AuthenticationState.signedOut(errorMessage: message));
        return;
      }
      _setState(_passwordRecoveryRequestSentState);
    }
  }

  Future<void> updatePassword({required String password}) async {
    if (_state.isSubmitting ||
        _state.status != AuthenticationStatus.passwordRecovery) {
      return;
    }
    final user = _state.user;
    if (user == null) {
      _setState(const AuthenticationState.signedOut());
      return;
    }

    final generation = _generation;
    _setState(_state.copyWith(isSubmitting: true, clearErrorMessage: true));
    try {
      await authRepository.updatePassword(password: password);
      if (!_current(generation)) return;
      await _loadProfileFor(user);
    } catch (error) {
      if (!_current(generation)) return;
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: AuthErrorMapper.messageFor(error),
        ),
      );
    }
  }

  Future<void> signOut() async {
    final previousState = _state;
    final generation = ++_generation;
    _setState(previousState.copyWith(isSubmitting: true));

    try {
      await authRepository.signOut();
      if (!_current(generation)) return;
      _setState(const AuthenticationState.signedOut());
    } catch (error) {
      if (!_current(generation)) return;
      _setState(
        previousState.copyWith(
          errorMessage: AuthErrorMapper.messageFor(error),
          isSubmitting: false,
        ),
      );
    }
  }

  void dismissVerificationMessage() {
    _generation += 1;
    _setState(const AuthenticationState.signedOut());
  }

  void accountDeleted() {
    _generation += 1;
    _setState(const AuthenticationState.signedOut());
  }

  Future<void> _handleAuthEvent(AuthSessionEvent event) async {
    switch (event.type) {
      case AuthSessionEventType.signedOut:
        _generation += 1;
        _setState(const AuthenticationState.signedOut());
      case AuthSessionEventType.passwordRecovery:
        _generation += 1;
        final user = event.user;
        if (user == null) {
          _setState(
            const AuthenticationState.signedOut(
              errorMessage:
                  'This password reset link is invalid or expired. Request a new one.',
            ),
          );
          return;
        }
        _setState(AuthenticationState.passwordRecovery(user: user));
      case AuthSessionEventType.signedIn:
      case AuthSessionEventType.tokenRefreshed:
      case AuthSessionEventType.userUpdated:
        final user = event.user;
        if (_state.status == AuthenticationStatus.passwordRecovery &&
            user?.id == _state.user?.id) {
          return;
        }
        if (event.type == AuthSessionEventType.tokenRefreshed &&
            user?.id == _state.user?.id &&
            _state.status != AuthenticationStatus.signedOut) {
          return;
        }
        if (user != null) {
          await _loadProfileFor(user);
        }
    }
  }

  static const _networkErrorMessage =
      'We could not reach OweLoop. Check your connection and try again.';
  static const _passwordRecoveryRequestSentState = AuthenticationState.signedOut(
    hasRequestedPasswordRecovery: true,
    noticeMessage:
        'If an account uses that email address, we sent password reset instructions.',
  );

  Future<void> _loadProfileFor(AuthenticatedUser user) async {
    final generation = ++_generation;
    _setState(
      AuthenticationState(status: AuthenticationStatus.loading, user: user),
    );

    try {
      final profile = await profileRepository.loadCurrentProfile();
      if (!_current(generation)) return;
      if (profile != null && profile.id != user.id) {
        throw const FormatException(
          'Profile identity did not match the session.',
        );
      }
      final status = profile?.hasCompletedOnboarding ?? false
          ? AuthenticationStatus.authenticated
          : AuthenticationStatus.profileSetup;

      _setState(
        AuthenticationState(status: status, user: user, profile: profile),
      );
    } catch (error) {
      if (!_current(generation)) return;
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
    _generation += 1;
    _isDisposed = true;
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
