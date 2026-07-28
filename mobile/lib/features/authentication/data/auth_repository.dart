import '../domain/auth_models.dart';

abstract interface class AuthRepository {
  Future<AuthenticatedUser?> restoreSession();

  Stream<AuthSessionEvent> get authEvents;

  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  });

  Future<SignUpResult> signUp({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
