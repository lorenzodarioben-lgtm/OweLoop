import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/presentation/loading_screen.dart';
import '../features/authentication/presentation/account_screen.dart';
import '../core/operations/pending_operations_screen.dart';
import '../features/authentication/presentation/auth_callback_screen.dart';
import '../features/authentication/presentation/forgot_password_screen.dart';
import '../features/authentication/presentation/profile_setup_screen.dart';
import '../features/authentication/presentation/sign_in_screen.dart';
import '../features/authentication/presentation/sign_up_screen.dart';
import '../features/authentication/presentation/verification_pending_screen.dart';
import '../features/authentication/presentation/update_password_screen.dart';
import '../features/authentication/state/authentication_controller.dart';
import '../features/authentication/state/authentication_providers.dart';
import '../features/authentication/state/authentication_state.dart';
import '../features/expenses/presentation/add_expense_screen.dart';
import '../features/expenses/presentation/expense_history_screen.dart';
import '../features/settlements/presentation/settlement_history_screen.dart';
import '../features/expenses/presentation/expense_detail_screen.dart';
import '../features/expenses/domain/expense_models.dart';
import '../features/expenses/domain/expense_template.dart';
import '../features/expenses/domain/expense_schedule.dart';
import '../features/expenses/presentation/expense_schedules_screen.dart';
import '../features/expenses/presentation/expense_templates_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/groups/presentation/create_group_screen.dart';
import '../features/groups/presentation/group_export_screen.dart';
import '../features/groups/presentation/group_detail_screen.dart';
import '../features/groups/presentation/group_list_screen.dart';
import '../features/groups/presentation/group_settings_screen.dart';
import '../features/guest_claims/presentation/guest_claim_inbox_screen.dart';
import '../features/invitations/presentation/invitation_inbox_screen.dart';
import '../features/settlements/domain/settlement_models.dart';
import '../features/settlements/presentation/record_settlement_screen.dart';

abstract final class AppRoutes {
  static const loading = '/loading';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const verifyEmail = '/verify-email';
  static const forgotPassword = '/forgot-password';
  static const authCallback = '/auth/callback';
  static const updatePassword = '/update-password';
  static const profileSetup = '/profile-setup';
  static const home = '/';
  static const invitations = '/invitations';
  static const guestClaims = '/guest-claims';
  static const pendingOperations = '/pending-submissions';
  static const account = '/account';
  static const notifications = '/notifications';
  static const newGroup = '/groups/new';
  static const groupDetail = '/groups/:groupId';
  static const groupSettings = '/groups/:groupId/settings';
  static const newExpense = '/groups/:groupId/expenses/new';
  static const expenseDetail = '/groups/:groupId/expenses/:expenseId';
  static const newSettlement = '/groups/:groupId/settlements/new';

  static String groupDetailPath(String groupId) => '/groups/$groupId';

  static String groupSettingsPath(String groupId) =>
      '/groups/$groupId/settings';

  static String newExpensePath(String groupId) =>
      '/groups/$groupId/expenses/new';

  static String expenseDetailPath(String groupId, String expenseId) =>
      '/groups/$groupId/expenses/$expenseId';

  static String newSettlementPath(String groupId) =>
      '/groups/$groupId/settlements/new';
  static String expenseHistoryPath(String groupId) =>
      '/groups/$groupId/expenses';
  static String settlementHistoryPath(String groupId) =>
      '/groups/$groupId/settlements';
  static String groupExportPath(String groupId) => '/groups/$groupId/exports';
  static String expenseTemplatesPath(String groupId) =>
      '/groups/$groupId/templates';
  static String expenseSchedulesPath(String groupId) =>
      '/groups/$groupId/schedules';
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
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.authCallback,
        builder: (context, state) => const AuthCallbackScreen(),
      ),
      GoRoute(
        path: AppRoutes.updatePassword,
        builder: (context, state) => const UpdatePasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const GroupListScreen(),
        routes: [
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: 'account',
            builder: (context, state) => const AccountScreen(),
          ),
          GoRoute(
            path: 'pending-submissions',
            builder: (context, state) => const PendingOperationsScreen(),
          ),
          GoRoute(
            path: 'invitations',
            builder: (context, state) => const InvitationInboxScreen(),
          ),
          GoRoute(
            path: 'guest-claims',
            builder: (context, state) => const GuestClaimInboxScreen(),
          ),
          GoRoute(
            path: 'groups/new',
            builder: (context, state) => const CreateGroupScreen(),
          ),
          GoRoute(
            path: 'groups/:groupId',
            builder: (context, state) =>
                GroupDetailScreen(groupId: state.pathParameters['groupId']!),
            routes: [
              GoRoute(
                path: 'schedules',
                builder: (context, state) => ExpenseSchedulesScreen(
                  groupId: state.pathParameters['groupId']!,
                ),
              ),
              GoRoute(
                path: 'templates',
                builder: (context, state) => ExpenseTemplatesScreen(
                  groupId: state.pathParameters['groupId']!,
                ),
              ),
              GoRoute(
                path: 'exports',
                builder: (context, state) => GroupExportScreen(
                  groupId: state.pathParameters['groupId']!,
                ),
              ),
              GoRoute(
                path: 'expenses',
                builder: (context, state) => ExpenseHistoryScreen(
                  groupId: state.pathParameters['groupId']!,
                ),
              ),
              GoRoute(
                path: 'settlements',
                builder: (context, state) => SettlementHistoryScreen(
                  groupId: state.pathParameters['groupId']!,
                ),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => GroupSettingsScreen(
                  groupId: state.pathParameters['groupId']!,
                ),
              ),
              GoRoute(
                path: 'expenses/new',
                builder: (context, state) => AddExpenseScreen(
                  groupId: state.pathParameters['groupId']!,
                  occurrence: state.extra is ExpenseOccurrence
                      ? state.extra! as ExpenseOccurrence
                      : null,
                  template: state.extra is ExpenseOccurrence
                      ? (state.extra! as ExpenseOccurrence).template
                      : state.extra is ExpenseTemplate
                      ? state.extra! as ExpenseTemplate
                      : null,
                  draft: state.extra is ExpenseRecord
                      ? state.extra! as ExpenseRecord
                      : null,
                ),
              ),
              GoRoute(
                path: 'expenses/:expenseId',
                builder: (context, state) => ExpenseDetailScreen(
                  groupId: state.pathParameters['groupId']!,
                  expenseId: state.pathParameters['expenseId']!,
                ),
              ),
              GoRoute(
                path: 'settlements/new',
                builder: (context, state) => RecordSettlementScreen(
                  groupId: state.pathParameters['groupId']!,
                  draft: state.extra is SettlementDraft
                      ? state.extra! as SettlementDraft
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/home', redirect: (context, state) => AppRoutes.home),
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
      AppRoutes.signIn ||
      AppRoutes.signUp ||
      AppRoutes.forgotPassword ||
      AppRoutes.authCallback => null,
      _ => AppRoutes.signIn,
    };
  }

  if (status == AuthenticationStatus.verificationPending) {
    return location == AppRoutes.verifyEmail ? null : AppRoutes.verifyEmail;
  }

  if (status == AuthenticationStatus.passwordRecovery) {
    return location == AppRoutes.updatePassword
        ? null
        : AppRoutes.updatePassword;
  }

  if (status == AuthenticationStatus.profileSetup) {
    return location == AppRoutes.profileSetup ? null : AppRoutes.profileSetup;
  }

  if (location == AppRoutes.home ||
      location == AppRoutes.account ||
      location == AppRoutes.notifications ||
      location == AppRoutes.pendingOperations ||
      location == AppRoutes.invitations ||
      location == AppRoutes.guestClaims ||
      location == AppRoutes.newGroup ||
      location.startsWith('/groups/')) {
    return null;
  }

  return AppRoutes.home;
}
