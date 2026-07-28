import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/app/app_bootstrap.dart';
import 'package:oweloop/features/authentication/data/supabase_auth_repository.dart';
import 'package:oweloop/features/authentication/domain/auth_models.dart';
import 'package:oweloop/features/authentication/state/authentication_providers.dart';

import 'fakes/authentication_fakes.dart';

void main() {
  Widget buildApp({
    required FakeAuthRepository authRepository,
    required FakeProfileRepository profileRepository,
  }) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        profileRepositoryProvider.overrideWithValue(profileRepository),
      ],
      child: const OweLoopBootstrap(),
    );
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    required FakeAuthRepository authRepository,
    required FakeProfileRepository profileRepository,
  }) async {
    addTearDown(authRepository.dispose);
    await tester.pumpWidget(
      buildApp(
        authRepository: authRepository,
        profileRepository: profileRepository,
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

  testWidgets('completes profile setup and shows the authenticated welcome', (
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

    expect(find.text('Welcome, Taylor'), findsOneWidget);
  });

  testWidgets('shows the authenticated home and signs out', (tester) async {
    final authRepository = FakeAuthRepository(restoredUser: testUser);
    final profileRepository = FakeProfileRepository(
      currentProfile: completedTestProfile,
    );

    await pumpApp(
      tester,
      authRepository: authRepository,
      profileRepository: profileRepository,
    );

    expect(find.text('Welcome, Taylor'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(authRepository.didSignOut, isTrue);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
