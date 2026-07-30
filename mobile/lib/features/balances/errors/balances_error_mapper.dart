import '../data/supabase_balances_repository.dart';

class BalancesErrorMapper {
  const BalancesErrorMapper._();

  static bool isUnavailable(Object error) {
    return _rawMessage(error).contains('group is unavailable');
  }

  static String messageFor(Object error) {
    final rawMessage = _rawMessage(error);

    if (rawMessage.contains('financial records are inconsistent')) {
      return "We couldn't calculate this group's balances right now.";
    }
    if (rawMessage.contains('group is unavailable') ||
        rawMessage.contains('not found') ||
        rawMessage.contains('no rows')) {
      return 'This group is unavailable.';
    }
    if (rawMessage.contains('permission') ||
        rawMessage.contains('active group member') ||
        rawMessage.contains('complete your profile')) {
      return 'You do not have permission to view these balances.';
    }
    if (rawMessage.contains('refresh token') ||
        rawMessage.contains('jwt expired') ||
        rawMessage.contains('session expired')) {
      return 'Your session has expired. Please sign in again.';
    }
    if (rawMessage.contains('network') ||
        rawMessage.contains('socket') ||
        rawMessage.contains('connection') ||
        rawMessage.contains('timeout')) {
      return 'We could not reach OweLoop. Check your connection and try again.';
    }

    return "We couldn't load this group's balances. Please try again.";
  }

  static String _rawMessage(Object error) {
    return switch (error) {
      BalancesRepositoryException(:final message) => message,
      _ => error.toString(),
    }.toLowerCase();
  }
}
