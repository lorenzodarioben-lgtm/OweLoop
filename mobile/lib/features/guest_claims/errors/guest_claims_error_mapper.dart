import '../domain/guest_claim_models.dart';

class GuestClaimsErrorMapper {
  const GuestClaimsErrorMapper._();

  static String messageFor(Object error) {
    final rawMessage = switch (error) {
      GuestClaimRepositoryException(:final message) => message,
      _ => error.toString(),
    }.toLowerCase();

    if (rawMessage.contains('valid email')) {
      return 'Enter a valid email address.';
    }
    if (rawMessage.contains('claim request is unavailable') ||
        rawMessage.contains('guest is unavailable') ||
        rawMessage.contains('already an active member')) {
      return 'This guest claim request is no longer available.';
    }
    if (rawMessage.contains('group is unavailable') ||
        rawMessage.contains('archived')) {
      return 'This group is unavailable for guest claiming.';
    }
    if (rawMessage.contains('permission') ||
        rawMessage.contains('only an active')) {
      return 'You do not have permission to manage guest claims for this group.';
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
    return 'Something went wrong. Please try again.';
  }
}
