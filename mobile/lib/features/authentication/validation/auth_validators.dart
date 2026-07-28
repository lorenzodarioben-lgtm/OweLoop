class AuthValidators {
  const AuthValidators._();

  static const int minimumPasswordLength = 8;
  static const int maximumDisplayNameLength = 80;

  static String? email(String? value) {
    final trimmedValue = value?.trim() ?? '';
    final isValid = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(trimmedValue);

    if (trimmedValue.isEmpty || !isValid) {
      return 'Enter a valid email address.';
    }

    if (trimmedValue.length > 254) {
      return 'Enter a shorter email address.';
    }

    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.length < minimumPasswordLength) {
      return 'Use at least $minimumPasswordLength characters.';
    }

    return null;
  }

  static String? passwordConfirmation({
    required String password,
    required String confirmation,
  }) {
    if (confirmation != password) {
      return 'Passwords do not match.';
    }

    return null;
  }

  static String? displayName(String? value) {
    final trimmedValue = value?.trim() ?? '';

    if (trimmedValue.isEmpty) {
      return 'Enter a display name.';
    }

    if (trimmedValue.length > maximumDisplayNameLength) {
      return 'Use $maximumDisplayNameLength characters or fewer.';
    }

    return null;
  }
}
