import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/app/app_bootstrap.dart';
import 'package:oweloop/features/authentication/data/supabase_auth_repository.dart';
import 'package:oweloop/features/authentication/domain/auth_models.dart';
import 'package:oweloop/features/authentication/state/authentication_providers.dart';
import 'package:oweloop/features/groups/state/groups_providers.dart';

import 'fakes/authentication_fakes.dart';
import 'fakes/groups_fakes.dart';

void main() {
  Widget buildApp({
    required FakeAuthRepository authRepository,
    required FakeProfileRepository profileRepository,
    FakeGroupsRepository? groupsRepository,
  }) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        profileRepositoryProvider.overrideWithValue(profileRepository),
        groupsRepositoryProvider.overrideWithValue(
          groupsRepository ?? FakeGroupsRepository(),
        ),
      ],
      child: const OweLoopBootstrap(),
    );
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    required FakeAuthRepository authRepository,
    required FakeProfileRepository profileRepository,
    FakeGroupsRepository? groupsRepository,
  }) async {
    addTearDown(authRepository.dispose);
    await tester.pumpWidget(
      buildApp(
        authRepository: authRepository,
        profileRepository: profileRepository,
        groupsRepository: groupsRepository,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows an accessible loading state while restoring a session', (
    tester,
  ) async {
    final restoreCompleter = Completer<AuthenticatedUser?>();
    final authRepository = FakeAuthRepository(restoredUser: null)
      ..restoreSessionHandler = () => restoreCompleter.future;
    final profileRepository = FakeProfileRepository();

    await tester.pumpWidget(
      buildApp(
        authRepository: authRepository,
        profileRepository: profileRepository,
      ),
    );
    await tester.pump();

    expect(find.text('Restoring your session…'), findsOneWidget);

    restoreCompleter.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('validates the sign-in form before submitting', (tester) async {
    final authRepository = FakeAuthRepository();
    final profileRepository = FakeProfileRepository();

    await pumpApp(
      tester,
      authRepository: authRepository,
      profileRepository: profileRepository,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
  });

  testWidgets('validates password confirmation on sign-up', (tester) async {
    final authRepository = FakeAuthRepository();
    final profileRepository = FakeProfileRepository();

    await pumpApp(
      tester,
      authRepository: authRepository,
      profileRepository: profileRepository,
    );

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'member@example.test');
    await tester.enterText(fields.at(1), 'long-enough');
    await tester.enterText(fields.at(2), 'different-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets(
    'shows the verification message after confirmation-only sign-up',
    (tester) async {
      final authRepository = FakeAuthRepository(
        signUpResult: SignUpResult.verificationRequired(email: testUser.email),
      );
      final profileRepository = FakeProfileRepository();

      await pumpApp(
        tester,
        authRepository: authRepository,
        profileRepository: profileRepository,
      );

      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), testUser.email);
      await tester.enterText(fields.at(1), 'long-enough');
      await tester.enterText(fields.at(2), 'long-enough');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.text('Back to sign in'), findsOneWidget);
    },
  );

  testWidgets('requests password reset without revealing account existence', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository();
    final profileRepository = FakeProfileRepository();
    await pumpApp(
      tester,
      authRepository: authRepository,
      profileRepository: profileRepository,
    );

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'unknown@example.test');
    await tester.tap(
      find.widgetWithText(FilledButton, 'Send reset instructions'),
    );
    await tester.pumpAndSettle();

    expect(authRepository.passwordRecoveryEmail, 'unknown@example.test');
    expect(
      find.text(
        'If an account uses that email address, we sent password reset instructions.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('resends an email verification request from the pending screen', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(
      signUpResult: SignUpResult.verificationRequired(email: testUser.email),
    );
    final profileRepository = FakeProfileRepository();
    await pumpApp(
      tester,
      authRepository: authRepository,
      profileRepository: profileRepository,
    );

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), testUser.email);
    await tester.enterText(fields.at(1), 'long-enough');
    await tester.enterText(fields.at(2), 'long-enough');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Resend verification email'),
    );
    await tester.pumpAndSettle();

    expect(authRepository.resentVerificationEmail, testUser.email);
    expect(
      find.textContaining('If confirmation is still needed'),
      findsOneWidget,
    );
  });

  testWidgets('updates a password only after a recovery callback', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository();
    final profileRepository = FakeProfileRepository(
      currentProfile: completedTestProfile,
    );
    await pumpApp(
      tester,
      authRepository: authRepository,
      profileRepository: profileRepository,
    );

    authRepository.emit(
      const AuthSessionEvent(
        type: AuthSessionEventType.passwordRecovery,
        user: testUser,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose a new password'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'new-long-password');
    await tester.enterText(fields.at(1), 'new-long-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Update password'));
    await tester.pumpAndSettle();

    expect(authRepository.updatedPassword, 'new-long-password');
    expect(find.text('Hi, Taylor'), findsOneWidget);
  });

  testWidgets('shows a safe error state for failed sign-in', (tester) async {
    final authRepository = FakeAuthRepository()
      ..signInError = const AuthenticationServiceException(
        'Invalid login credentials',
      );
    final profileRepository = FakeProfileRepository();

    await pumpApp(
      tester,
      authRepository: authRepository,
      profileRepository: profileRepository,
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), testUser.email);
    await tester.enterText(fields.at(1), 'long-enough');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.text('Check your email address and password, then try again.'),
      findsOneWidget,
    );
  });

  testWidgets('completes profile setup and shows the group home', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(restoredUser: testUser);
    final profileRepository = FakeProfileRepository(
      currentProfile: incompleteTestProfile,
      completedProfile: completedTestProfile,
    );

    await pumpApp(
      tester,
      authRepository: authRepository,
      profileRepository: profileRepository,
    );

    expect(find.text('Choose your display name'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Taylor');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Hi, Taylor'), findsOneWidget);
  });

  testWidgets('shows the group home and signs out', (tester) async {
    final authRepository = FakeAuthRepository(restoredUser: testUser);
    final profileRepository = FakeProfileRepository(
      currentProfile: completedTestProfile,
    );

    await pumpApp(
      tester,
      authRepository: authRepository,
      profileRepository: profileRepository,
    );

    expect(find.text('Hi, Taylor'), findsOneWidget);
    expect(find.text('Create your first group'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(authRepository.didSignOut, isTrue);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
