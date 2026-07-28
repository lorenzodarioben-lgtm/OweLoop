import '../data/supabase_groups_repository.dart';

class GroupsErrorMapper {
  const GroupsErrorMapper._();

  static String messageFor(Object error) {
    final rawMessage = switch (error) {
      GroupsRepositoryException(:final message) => message,
      _ => error.toString(),
    }.toLowerCase();

    if (rawMessage.contains('guest display name')) {
      return 'Enter a valid guest name.';
    }

    if (rawMessage.contains('group name') ||
        rawMessage.contains('name cannot')) {
      return 'Enter a valid group name.';
    }

    if (rawMessage.contains('currency')) {
      return 'Choose a valid currency for this group.';
    }

    if (rawMessage.contains('archived')) {
      return 'This group is archived and cannot be changed.';
    }

    if (rawMessage.contains('group is unavailable') ||
        rawMessage.contains('not found') ||
        rawMessage.contains('no rows')) {
      return 'This group is unavailable.';
    }

    if (rawMessage.contains('permission') ||
        rawMessage.contains('only an active') ||
        rawMessage.contains('complete your profile')) {
      return 'You do not have permission to do that.';
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
