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

  test('resends verification with generic success feedback', () async {
    authRepository.signUpResult = SignUpResult.verificationRequired(
      email: testUser.email,
    );
    await controller.initialize();
    await controller.signUp(email: testUser.email, password: 'long-enough');

    await controller.resendVerification();

    expect(authRepository.resentVerificationEmail, testUser.email);
    expect(controller.state.status, AuthenticationStatus.verificationPending);
    expect(controller.state.noticeMessage, contains('If confirmation'));
  });

  test('requests password recovery with enumeration-safe feedback', () async {
    await controller.initialize();

    await controller.requestPasswordRecovery(email: 'unknown@example.test');

    expect(authRepository.passwordRecoveryEmail, 'unknown@example.test');
    expect(controller.state.status, AuthenticationStatus.signedOut);
    expect(controller.state.hasRequestedPasswordRecovery, isTrue);
    expect(controller.state.noticeMessage, contains('If an account uses'));
  });

  test(
    'requires a recovery auth event before allowing a password update',
    () async {
      profileRepository.currentProfile = completedTestProfile;
      await controller.initialize();
      authRepository.emit(
        const AuthSessionEvent(
          type: AuthSessionEventType.passwordRecovery,
          user: testUser,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.status, AuthenticationStatus.passwordRecovery);
      await controller.updatePassword(password: 'new-long-password');

      expect(authRepository.updatedPassword, 'new-long-password');
      expect(controller.state.status, AuthenticationStatus.authenticated);
    },
  );

  test('handles missing or expired recovery state safely', () async {
    await controller.initialize();
    authRepository.emit(
      const AuthSessionEvent(type: AuthSessionEventType.passwordRecovery),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.status, AuthenticationStatus.signedOut);
    expect(controller.state.errorMessage, contains('invalid or expired'));
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
