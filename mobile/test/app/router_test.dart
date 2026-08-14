import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/app/router.dart';
import 'package:oweloop/features/authentication/domain/auth_models.dart';
import 'package:oweloop/features/authentication/state/authentication_state.dart';

void main() {
  const user = AuthenticatedUser(
    id: '11111111-1111-1111-1111-111111111111',
    email: 'member@example.test',
  );

  group('authenticationRedirect', () {
    test('keeps loading separate from signed-out routing', () {
      expect(
        authenticationRedirect(
          authenticationState: const AuthenticationState.loading(),
          location: AppRoutes.home,
        ),
        AppRoutes.loading,
      );
    });

    test('protects authenticated routes from signed-out users', () {
      expect(
        authenticationRedirect(
          authenticationState: const AuthenticationState.signedOut(),
          location: AppRoutes.home,
        ),
        AppRoutes.signIn,
      );
    });

    test('allows signed-out recovery requests and auth callbacks', () {
      const signedOut = AuthenticationState.signedOut();
      expect(
        authenticationRedirect(
          authenticationState: signedOut,
          location: AppRoutes.forgotPassword,
        ),
        isNull,
      );
      expect(
        authenticationRedirect(
          authenticationState: signedOut,
          location: AppRoutes.authCallback,
        ),
        isNull,
      );
    });

    test('only a recovery session can access password update', () {
      expect(
        authenticationRedirect(
          authenticationState: const AuthenticationState.signedOut(),
          location: AppRoutes.updatePassword,
        ),
        AppRoutes.signIn,
      );
      expect(
        authenticationRedirect(
          authenticationState: AuthenticationState.passwordRecovery(user: user),
          location: AppRoutes.home,
        ),
        AppRoutes.updatePassword,
      );
    });

    test('protects group routes from signed-out users', () {
      expect(
        authenticationRedirect(
          authenticationState: const AuthenticationState.signedOut(),
          location: AppRoutes.groupDetailPath('private-group'),
        ),
        AppRoutes.signIn,
      );
    });

    test('protects expense routes from signed-out users', () {
      expect(
        authenticationRedirect(
          authenticationState: const AuthenticationState.signedOut(),
          location: AppRoutes.expenseDetailPath('private-group', 'expense-id'),
        ),
        AppRoutes.signIn,
      );
    });

    test('sends incomplete profiles to profile setup', () {
      expect(
        authenticationRedirect(
          authenticationState: AuthenticationState(
            status: AuthenticationStatus.profileSetup,
            user: user,
          ),
          location: AppRoutes.home,
        ),
        AppRoutes.profileSetup,
      );
    });

    test('protects group routes from incomplete profiles', () {
      expect(
        authenticationRedirect(
          authenticationState: AuthenticationState(
            status: AuthenticationStatus.profileSetup,
            user: user,
          ),
          location: AppRoutes.newGroup,
        ),
        AppRoutes.profileSetup,
      );
    });

    test('protects expense routes from incomplete profiles', () {
      expect(
        authenticationRedirect(
          authenticationState: AuthenticationState(
            status: AuthenticationStatus.profileSetup,
            user: user,
          ),
          location: AppRoutes.newExpensePath('group-id'),
        ),
        AppRoutes.profileSetup,
      );
    });

    test('sends completed profiles away from auth screens', () {
      expect(
        authenticationRedirect(
          authenticationState: AuthenticationState(
            status: AuthenticationStatus.authenticated,
            user: user,
          ),
          location: AppRoutes.signIn,
        ),
        AppRoutes.home,
      );
    });

    test('allows authenticated users onto protected group routes', () {
      expect(
        authenticationRedirect(
          authenticationState: AuthenticationState(
            status: AuthenticationStatus.authenticated,
            user: user,
          ),
          location: AppRoutes.groupDetailPath('group-id'),
        ),
        isNull,
      );
    });

    test('allows authenticated users onto protected expense routes', () {
      expect(
        authenticationRedirect(
          authenticationState: AuthenticationState(
            status: AuthenticationStatus.authenticated,
            user: user,
          ),
          location: AppRoutes.expenseDetailPath('group-id', 'expense-id'),
        ),
        isNull,
      );
    });
  });
}
