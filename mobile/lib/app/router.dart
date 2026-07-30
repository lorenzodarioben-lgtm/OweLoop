import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/presentation/loading_screen.dart';
import '../features/authentication/presentation/profile_setup_screen.dart';
import '../features/authentication/presentation/sign_in_screen.dart';
import '../features/authentication/presentation/sign_up_screen.dart';
import '../features/authentication/presentation/verification_pending_screen.dart';
import '../features/authentication/state/authentication_controller.dart';
import '../features/authentication/state/authentication_providers.dart';
import '../features/authentication/state/authentication_state.dart';
import '../features/expenses/presentation/add_expense_screen.dart';
import '../features/expenses/presentation/expense_detail_screen.dart';
import '../features/groups/presentation/create_group_screen.dart';
import '../features/groups/presentation/group_detail_screen.dart';
import '../features/groups/presentation/group_list_screen.dart';

abstract final class AppRoutes {
  static const loading = '/loading';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const verifyEmail = '/verify-email';
  static const profileSetup = '/profile-setup';
  static const home = '/home';
  static const newGroup = '/groups/new';
  static const groupDetail = '/groups/:groupId';
  static const newExpense = '/groups/:groupId/expenses/new';
  static const expenseDetail = '/groups/:groupId/expenses/:expenseId';

  static String groupDetailPath(String groupId) => '/groups/$groupId';

  static String newExpensePath(String groupId) =>
      '/groups/$groupId/expenses/new';

  static String expenseDetailPath(String groupId, String expenseId) =>
      '/groups/$groupId/expenses/$expenseId';
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
        builder: (context, state) => const GroupListScreen(),
      ),
      GoRoute(
        path: AppRoutes.newGroup,
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: AppRoutes.groupDetail,
        builder: (context, state) =>
            GroupDetailScreen(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(
        path: AppRoutes.newExpense,
        builder: (context, state) =>
            AddExpenseScreen(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(
        path: AppRoutes.expenseDetail,
        builder: (context, state) => ExpenseDetailScreen(
          groupId: state.pathParameters['groupId']!,
          expenseId: state.pathParameters['expenseId']!,
        ),
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

  if (location == AppRoutes.home ||
      location == AppRoutes.newGroup ||
      location.startsWith('/groups/')) {
    return null;
  }

  return AppRoutes.home;
}
