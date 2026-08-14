import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/authentication/data/supabase_auth_repository.dart';
import 'package:oweloop/features/authentication/errors/auth_error_mapper.dart';

void main() {
  group('AuthErrorMapper', () {
    test('maps invalid credentials to a safe message', () {
      expect(
        AuthErrorMapper.messageFor(
          const AuthenticationServiceException('Invalid login credentials'),
        ),
        'Check your email address and password, then try again.',
      );
    });

    test('maps unconfirmed email to verification guidance', () {
      expect(
        AuthErrorMapper.messageFor(
          const AuthenticationServiceException('Email not confirmed'),
        ),
        'Verify your email address before signing in.',
      );
    });

    test('does not reveal unexpected backend details', () {
      expect(
        AuthErrorMapper.messageFor(
          const AuthenticationServiceException(
            'postgres failure with an internal detail',
          ),
        ),
        'Something went wrong. Please try again.',
      );
    });

    test('maps expired recovery links to a safe recovery action', () {
      expect(
        AuthErrorMapper.messageFor(
          const AuthenticationServiceException('Auth code has expired'),
        ),
        'This password reset link is invalid or expired. Request a new one.',
      );
    });
  });
}
