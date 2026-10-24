import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/authentication/domain/auth_models.dart';
import 'package:oweloop/features/authentication/domain/app_profile.dart';
import 'package:oweloop/features/authentication/state/authentication_controller.dart';
import 'package:oweloop/features/authentication/state/authentication_state.dart';
import '../../fakes/authentication_fakes.dart';

void main() {
  Future<void> tick() => Future<void>.delayed(Duration.zero);
  test('sign-out invalidates a delayed restoration', () async {
    final pending = Completer<AuthenticatedUser?>();
    final auth = FakeAuthRepository()
      ..restoreSessionHandler = () => pending.future;
    final controller = AuthenticationController(
      authRepository: auth,
      profileRepository: FakeProfileRepository(
        currentProfile: completedTestProfile,
      ),
    );
    final initialization = controller.initialize();
    auth.emit(const AuthSessionEvent(type: AuthSessionEventType.signedOut));
    await tick();
    pending.complete(testUser);
    await initialization;
    expect(controller.state.status, AuthenticationStatus.signedOut);
    controller.dispose();
    await auth.dispose();
  });
  test('sign-out and disposal invalidate delayed profile completion', () async {
    for (final dispose in [false, true]) {
      final pending = Completer<AppProfile?>();
      final auth = FakeAuthRepository();
      final profiles = FakeProfileRepository()
        ..loadHandler = () => pending.future;
      final controller = AuthenticationController(
        authRepository: auth,
        profileRepository: profiles,
      );
      await controller.initialize();
      auth.emit(
        const AuthSessionEvent(
          type: AuthSessionEventType.signedIn,
          user: testUser,
        ),
      );
      await tick();
      auth.emit(const AuthSessionEvent(type: AuthSessionEventType.signedOut));
      await tick();
      if (dispose) controller.dispose();
      pending.complete(completedTestProfile);
      await tick();
      expect(controller.state.status, AuthenticationStatus.signedOut);
      if (!dispose) controller.dispose();
      await auth.dispose();
    }
  });
  test('account B wins even when account A profile arrives last', () async {
    final first = Completer<AppProfile?>();
    const other = AuthenticatedUser(
      id: 'other-user',
      email: 'other@example.test',
    );
    final otherProfile = AppProfile(
      id: other.id,
      displayName: 'Other',
      onboardingCompletedAt: DateTime.utc(2026),
    );
    var loads = 0;
    final profiles = FakeProfileRepository()
      ..loadHandler = () =>
          ++loads == 1 ? first.future : Future.value(otherProfile);
    final auth = FakeAuthRepository();
    final controller = AuthenticationController(
      authRepository: auth,
      profileRepository: profiles,
    );
    await controller.initialize();
    auth.emit(
      const AuthSessionEvent(
        type: AuthSessionEventType.signedIn,
        user: testUser,
      ),
    );
    await tick();
    auth.emit(
      const AuthSessionEvent(type: AuthSessionEventType.signedIn, user: other),
    );
    await tick();
    first.complete(completedTestProfile);
    await tick();
    expect(controller.state.user?.id, other.id);
    expect(controller.state.profile?.id, other.id);
    controller.dispose();
    await auth.dispose();
  });
  test(
    'refresh and user events preserve password recovery until explicit update',
    () async {
      final auth = FakeAuthRepository();
      final controller = AuthenticationController(
        authRepository: auth,
        profileRepository: FakeProfileRepository(
          currentProfile: completedTestProfile,
        ),
      );
      await controller.initialize();
      auth.emit(
        const AuthSessionEvent(
          type: AuthSessionEventType.passwordRecovery,
          user: testUser,
        ),
      );
      await tick();
      for (final event in [
        AuthSessionEventType.tokenRefreshed,
        AuthSessionEventType.userUpdated,
      ]) {
        auth.emit(AuthSessionEvent(type: event, user: testUser));
        await tick();
        expect(controller.state.status, AuthenticationStatus.passwordRecovery);
      }
      await controller.updatePassword(password: 'long-new-password');
      expect(controller.state.status, AuthenticationStatus.authenticated);
      controller.dispose();
      await auth.dispose();
    },
  );
}
