import 'dart:async';

import 'package:oweloop/features/authentication/data/auth_repository.dart';
import 'package:oweloop/features/authentication/data/profile_repository.dart';
import 'package:oweloop/features/authentication/domain/app_profile.dart';
import 'package:oweloop/features/authentication/domain/auth_models.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.restoredUser, this.signInUser, this.signUpResult});

  AuthenticatedUser? restoredUser;
  AuthenticatedUser? signInUser;
  SignUpResult? signUpResult;
  Object? restoreError;
  Object? signInError;
  Object? signUpError;
  Object? resendVerificationError;
  Object? passwordRecoveryError;
  Object? updatePasswordError;
  Object? signOutError;
  Future<AuthenticatedUser?> Function()? restoreSessionHandler;
  bool didSignOut = false;
  String? resentVerificationEmail;
  String? passwordRecoveryEmail;
  String? updatedPassword;

  final StreamController<AuthSessionEvent> _events =
      StreamController<AuthSessionEvent>.broadcast();

  @override
  Stream<AuthSessionEvent> get authEvents => _events.stream;

  @override
  Future<AuthenticatedUser?> restoreSession() async {
    if (restoreSessionHandler != null) {
      return restoreSessionHandler!();
    }
    if (restoreError != null) {
      throw restoreError!;
    }
    return restoredUser;
  }

  @override
  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  }) async {
    if (signInError != null) {
      throw signInError!;
    }
    return signInUser ??
        (throw StateError('No sign-in user was configured for this test.'));
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    if (signUpError != null) {
      throw signUpError!;
    }
    return signUpResult ??
        (throw StateError('No sign-up result was configured for this test.'));
  }

  @override
  Future<void> resendVerification({required String email}) async {
    resentVerificationEmail = email;
    if (resendVerificationError != null) throw resendVerificationError!;
  }

  @override
  Future<void> requestPasswordRecovery({required String email}) async {
    passwordRecoveryEmail = email;
    if (passwordRecoveryError != null) throw passwordRecoveryError!;
  }

  @override
  Future<void> updatePassword({required String password}) async {
    updatedPassword = password;
    if (updatePasswordError != null) throw updatePasswordError!;
  }

  @override
  Future<void> signOut() async {
    if (signOutError != null) {
      throw signOutError!;
    }
    didSignOut = true;
  }

  void emit(AuthSessionEvent event) => _events.add(event);

  void emitError(Object error) => _events.addError(error);

  Future<void> dispose() => _events.close();
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.currentProfile, this.completedProfile});

  AppProfile? currentProfile;
  AppProfile? completedProfile;
  Object? loadError;
  Object? completeError;
  String? completedDisplayName;

  @override
  Future<AppProfile?> loadCurrentProfile() async {
    if (loadError != null) {
      throw loadError!;
    }
    return currentProfile;
  }

  @override
  Future<AppProfile> completeProfile({required String displayName}) async {
    completedDisplayName = displayName;
    if (completeError != null) {
      throw completeError!;
    }
    return completedProfile ??
        (throw StateError(
          'No completed profile was configured for this test.',
        ));
  }
}

const testUser = AuthenticatedUser(
  id: '11111111-1111-1111-1111-111111111111',
  email: 'member@example.test',
);

final incompleteTestProfile = AppProfile(
  id: testUser.id,
  displayName: 'Member',
  onboardingCompletedAt: null,
);

final completedTestProfile = AppProfile(
  id: testUser.id,
  displayName: 'Taylor',
  onboardingCompletedAt: DateTime.utc(2026, 7, 28),
);
