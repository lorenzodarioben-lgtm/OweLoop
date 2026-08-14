class AuthenticatedUser {
  const AuthenticatedUser({required this.id, required this.email});

  final String id;
  final String email;
}

enum AuthSessionEventType {
  signedIn,
  signedOut,
  passwordRecovery,
  tokenRefreshed,
  userUpdated,
}

class AuthSessionEvent {
  const AuthSessionEvent({required this.type, this.user});

  final AuthSessionEventType type;
  final AuthenticatedUser? user;
}

enum SignUpDisposition { authenticated, verificationRequired }

class SignUpResult {
  const SignUpResult._({
    required this.disposition,
    required this.email,
    this.user,
  });

  SignUpResult.authenticated({required AuthenticatedUser user})
    : this._(
        disposition: SignUpDisposition.authenticated,
        email: user.email,
        user: user,
      );

  const SignUpResult.verificationRequired({required String email})
    : this._(disposition: SignUpDisposition.verificationRequired, email: email);

  final SignUpDisposition disposition;
  final String email;
  final AuthenticatedUser? user;
}
