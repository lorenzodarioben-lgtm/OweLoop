import '../data/supabase_auth_repository.dart';

class AuthErrorMapper {
  const AuthErrorMapper._();

  static String messageFor(Object error) {
    final rawMessage = switch (error) {
      AuthenticationServiceException(:final message) => message,
      _ => error.toString(),
    }.toLowerCase();

    if (rawMessage.contains('invalid login credentials') ||
        rawMessage.contains('invalid credentials')) {
      return 'Check your email address and password, then try again.';
    }

    if (rawMessage.contains('email not confirmed') ||
        rawMessage.contains('email_not_confirmed')) {
      return 'Verify your email address before signing in.';
    }

    if (rawMessage.contains('already registered') ||
        rawMessage.contains('already been registered') ||
        rawMessage.contains('user already exists')) {
      return 'An account already exists for that email address.';
    }

    if (rawMessage.contains('password') &&
        (rawMessage.contains('weak') ||
            rawMessage.contains('least') ||
            rawMessage.contains('short'))) {
      return 'Choose a stronger password with at least 8 characters.';
    }

    if (rawMessage.contains('email') &&
        (rawMessage.contains('invalid') ||
            rawMessage.contains('malformed') ||
            rawMessage.contains('valid'))) {
      return 'Enter a valid email address.';
    }

    if (rawMessage.contains('network') ||
        rawMessage.contains('socket') ||
        rawMessage.contains('connection') ||
        rawMessage.contains('timeout')) {
      return 'We could not reach OweLoop. Check your connection and try again.';
    }

    if (rawMessage.contains('refresh token') ||
        rawMessage.contains('jwt expired') ||
        rawMessage.contains('session expired')) {
      return 'Your session has expired. Please sign in again.';
    }

    if (rawMessage.contains('expired') ||
        (rawMessage.contains('invalid') && rawMessage.contains('link')) ||
        rawMessage.contains('code verifier') ||
        rawMessage.contains('auth code')) {
      return 'This password reset link is invalid or expired. Request a new one.';
    }

    return 'Something went wrong. Please try again.';
  }
}
