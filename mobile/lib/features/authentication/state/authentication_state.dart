import '../domain/app_profile.dart';
import '../domain/auth_models.dart';

enum AuthenticationStatus {
  loading,
  signedOut,
  verificationPending,
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
    this.isSubmitting = false,
  });

  const AuthenticationState.loading()
    : this(status: AuthenticationStatus.loading);

  const AuthenticationState.signedOut({String? errorMessage})
    : this(status: AuthenticationStatus.signedOut, errorMessage: errorMessage);

  const AuthenticationState.verificationPending({required String email})
    : this(
        status: AuthenticationStatus.verificationPending,
        pendingEmail: email,
      );

  final AuthenticationStatus status;
  final AuthenticatedUser? user;
  final AppProfile? profile;
  final String? pendingEmail;
  final String? errorMessage;
  final bool isSubmitting;

  AuthenticationState copyWith({
    AuthenticationStatus? status,
    AuthenticatedUser? user,
    AppProfile? profile,
    String? pendingEmail,
    String? errorMessage,
    bool? isSubmitting,
    bool clearUser = false,
    bool clearProfile = false,
    bool clearPendingEmail = false,
    bool clearErrorMessage = false,
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
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}
