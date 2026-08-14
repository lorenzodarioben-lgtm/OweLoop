import '../domain/app_profile.dart';
import '../domain/auth_models.dart';

enum AuthenticationStatus {
  loading,
  signedOut,
  verificationPending,
  passwordRecovery,
  profileSetup,
  authenticated,
}

class AuthenticationState {
  const AuthenticationState({
    required this.status,
    this.user,
    this.profile,
    this.pendingEmail,
    this.errorMessage,
    this.noticeMessage,
    this.hasRequestedPasswordRecovery = false,
    this.isSubmitting = false,
  });

  const AuthenticationState.loading()
    : this(status: AuthenticationStatus.loading);

  const AuthenticationState.signedOut({
    String? errorMessage,
    String? noticeMessage,
    bool hasRequestedPasswordRecovery = false,
  }) : this(
         status: AuthenticationStatus.signedOut,
         errorMessage: errorMessage,
         noticeMessage: noticeMessage,
         hasRequestedPasswordRecovery: hasRequestedPasswordRecovery,
       );

  const AuthenticationState.verificationPending({required String email})
    : this(
        status: AuthenticationStatus.verificationPending,
        pendingEmail: email,
      );

  const AuthenticationState.passwordRecovery({required AuthenticatedUser user})
    : this(status: AuthenticationStatus.passwordRecovery, user: user);

  final AuthenticationStatus status;
  final AuthenticatedUser? user;
  final AppProfile? profile;
  final String? pendingEmail;
  final String? errorMessage;
  final String? noticeMessage;
  final bool hasRequestedPasswordRecovery;
  final bool isSubmitting;

  AuthenticationState copyWith({
    AuthenticationStatus? status,
    AuthenticatedUser? user,
    AppProfile? profile,
    String? pendingEmail,
    String? errorMessage,
    String? noticeMessage,
    bool? hasRequestedPasswordRecovery,
    bool? isSubmitting,
    bool clearUser = false,
    bool clearProfile = false,
    bool clearPendingEmail = false,
    bool clearErrorMessage = false,
    bool clearNoticeMessage = false,
  }) {
    return AuthenticationState(
      status: status ?? this.status,
      user: clearUser ? null : user ?? this.user,
      profile: clearProfile ? null : profile ?? this.profile,
      pendingEmail: clearPendingEmail
          ? null
          : pendingEmail ?? this.pendingEmail,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      noticeMessage: clearNoticeMessage
          ? null
          : noticeMessage ?? this.noticeMessage,
      hasRequestedPasswordRecovery:
          hasRequestedPasswordRecovery ?? this.hasRequestedPasswordRecovery,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}
