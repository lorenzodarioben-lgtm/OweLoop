import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/authentication/data/supabase_auth_repository.dart';
import 'package:oweloop/features/authentication/domain/auth_models.dart';
import 'package:oweloop/features/authentication/state/authentication_controller.dart';
import 'package:oweloop/features/authentication/state/authentication_state.dart';

import '../../fakes/authentication_fakes.dart';

void main() {
  late FakeAuthRepository authRepository;
  late FakeProfileRepository profileRepository;
  late AuthenticationController controller;

  setUp(() {
    authRepository = FakeAuthRepository();
    profileRepository = FakeProfileRepository();
    controller = AuthenticationController(
      authRepository: authRepository,
      profileRepository: profileRepository,
    );
  });

  tearDown(() async {
    controller.dispose();
    await authRepository.dispose();
  });

  test('restores a completed session safely', () async {
    authRepository.restoredUser = testUser;
    profileRepository.currentProfile = completedTestProfile;

    await controller.initialize();

    expect(controller.state.status, AuthenticationStatus.authenticated);
    expect(controller.state.profile?.displayName, 'Taylor');
  });

  test(
    'moves a successful sign-in with an incomplete profile to setup',
    () async {
      authRepository.signInUser = testUser;
      profileRepository.currentProfile = incompleteTestProfile;
      await controller.initialize();

      await controller.signIn(email: testUser.email, password: 'long-enough');

      expect(controller.state.status, AuthenticationStatus.profileSetup);
    },
  );

  test('maps a failed sign-in to a safe signed-out error', () async {
    authRepository.signInError = const AuthenticationServiceException(
      'Invalid login credentials',
    );
    await controller.initialize();

    await controller.signIn(email: testUser.email, password: 'long-enough');

    expect(controller.state.status, AuthenticationStatus.signedOut);
    expect(
      controller.state.errorMessage,
      'Check your email address and password, then try again.',
    );
  });

  test('handles immediate-session sign-up', () async {
    authRepository.signUpResult = SignUpResult.authenticated(user: testUser);
    profileRepository.currentProfile = incompleteTestProfile;
    await controller.initialize();

    await controller.signUp(email: testUser.email, password: 'long-enough');

    expect(controller.state.status, AuthenticationStatus.profileSetup);
  });

  test('handles sign-up requiring email verification', () async {
    authRepository.signUpResult = SignUpResult.verificationRequired(
      email: testUser.email,
    );
    await controller.initialize();

    await controller.signUp(email: testUser.email, password: 'long-enough');

    expect(controller.state.status, AuthenticationStatus.verificationPending);
    expect(controller.state.pendingEmail, testUser.email);
  });

  test('completes a profile and enters the authenticated state', () async {
    authRepository.restoredUser = testUser;
    profileRepository.currentProfile = incompleteTestProfile;
    profileRepository.completedProfile = completedTestProfile;
    await controller.initialize();

    await controller.completeProfile(displayName: 'Taylor');

    expect(controller.state.status, AuthenticationStatus.authenticated);
    expect(profileRepository.completedDisplayName, 'Taylor');
  });

  test('keeps the profile setup state when completion fails', () async {
    authRepository.restoredUser = testUser;
    profileRepository.currentProfile = incompleteTestProfile;
    profileRepository.completeError = const AuthenticationServiceException(
      'network failure',
    );
    await controller.initialize();

    await controller.completeProfile(displayName: 'Taylor');

    expect(controller.state.status, AuthenticationStatus.profileSetup);
    expect(
      controller.state.errorMessage,
      'We could not reach OweLoop. Check your connection and try again.',
    );
  });

  test('clears session and profile state after sign-out', () async {
    authRepository.restoredUser = testUser;
    profileRepository.currentProfile = completedTestProfile;
    await controller.initialize();

    await controller.signOut();

    expect(authRepository.didSignOut, isTrue);
    expect(controller.state.status, AuthenticationStatus.signedOut);
    expect(controller.state.profile, isNull);
    expect(controller.state.user, isNull);
  });
}
