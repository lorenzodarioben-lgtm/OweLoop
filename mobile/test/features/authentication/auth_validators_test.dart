import 'package:flutter_test/flutter_test.dart';
import 'package:oweloop/features/authentication/validation/auth_validators.dart';

void main() {
  group('AuthValidators', () {
    test('validates email addresses after trimming whitespace', () {
      expect(AuthValidators.email(' member@example.test '), isNull);
      expect(AuthValidators.email('not-an-email'), isNotNull);
    });

    test('requires a minimum password length', () {
      expect(AuthValidators.password('short'), isNotNull);
      expect(AuthValidators.password('long-enough'), isNull);
    });

    test('requires matching password confirmation', () {
      expect(
        AuthValidators.passwordConfirmation(
          password: 'long-enough',
          confirmation: 'different',
        ),
        isNotNull,
      );
      expect(
        AuthValidators.passwordConfirmation(
          password: 'long-enough',
          confirmation: 'long-enough',
        ),
        isNull,
      );
    });

    test('validates display names after trimming whitespace', () {
      expect(AuthValidators.displayName('  Taylor  '), isNull);
      expect(AuthValidators.displayName('   '), isNotNull);
      expect(AuthValidators.displayName('x' * 81), isNotNull);
    });
  });
}
