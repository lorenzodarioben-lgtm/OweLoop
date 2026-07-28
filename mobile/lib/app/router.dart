import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/presentation/authenticated_home_screen.dart';
import '../features/authentication/presentation/loading_screen.dart';
import '../features/authentication/presentation/profile_setup_screen.dart';
import '../features/authentication/presentation/sign_in_screen.dart';
import '../features/authentication/presentation/sign_up_screen.dart';
import '../features/authentication/presentation/verification_pending_screen.dart';
import '../features/authentication/state/authentication_controller.dart';
import '../features/authentication/state/authentication_providers.dart';
import '../features/authentication/state/authentication_state.dart';

abstract final class AppRoutes {
  static const loading = '/loading';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const verifyEmail = '/verify-email';
  static const profileSetup = '/profile-setup';
  static const home = '/home';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final controller = ref.read(authenticationControllerProvider);
  final router = createAppRouter(controller);
  ref.onDispose(router.dispose);
  return router;
});

GoRouter createAppRouter(AuthenticationController controller) {
  return GoRouter(
    initialLocation: AppRoutes.loading,
    refreshListenable: controller,
    redirect: (context, state) => authenticationRedirect(
      authenticationState: controller.state,
      location: state.uri.path,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.loading,
        builder: (context, state) => const AuthenticationLoadingScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) => const VerificationPendingScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const AuthenticatedHomeScreen(),
      ),
    ],
  );
}

String? authenticationRedirect({
  required AuthenticationState authenticationState,
  required String location,
}) {
  final status = authenticationState.status;

  if (status == AuthenticationStatus.loading) {
    return location == AppRoutes.loading ? null : AppRoutes.loading;
  }

  if (status == AuthenticationStatus.signedOut) {
    return switch (location) {
      AppRoutes.signIn || AppRoutes.signUp => null,
      _ => AppRoutes.signIn,
    };
  }

  if (status == AuthenticationStatus.verificationPending) {
    return location == AppRoutes.verifyEmail ? null : AppRoutes.verifyEmail;
  }

  if (status == AuthenticationStatus.profileSetup) {
    return location == AppRoutes.profileSetup ? null : AppRoutes.profileSetup;
  }

  return location == AppRoutes.home ? null : AppRoutes.home;
}
