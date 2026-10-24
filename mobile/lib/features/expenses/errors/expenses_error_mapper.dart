import '../data/supabase_expenses_repository.dart';
import '../../../core/operations/pending_financial_operations.dart';

class ExpensesErrorMapper {
  const ExpensesErrorMapper._();

  static String messageFor(Object error) {
    if (error is FinancialOperationException) return error.message;
    final rawMessage = switch (error) {
      ExpensesRepositoryException(:final message) => message,
      _ => error.toString(),
    }.toLowerCase();

    if (rawMessage.contains('description')) {
      return 'Enter a valid expense description.';
    }
    if (rawMessage.contains('total') || rawMessage.contains('amount')) {
      return 'Enter a valid positive amount.';
    }
    if (rawMessage.contains('participant')) {
      return 'Select valid group participants.';
    }
    if (rawMessage.contains('payer')) {
      return 'Choose a valid payer from this group.';
    }
    if (rawMessage.contains('archived')) {
      return 'This group is archived and cannot be changed.';
    }
    if (rawMessage.contains('already voided')) {
      return 'This expense has already been voided.';
    }
    if (rawMessage.contains('unavailable') ||
        rawMessage.contains('not found') ||
        rawMessage.contains('no rows')) {
      return 'This expense is unavailable.';
    }
    if (rawMessage.contains('permission') ||
        rawMessage.contains('active group member') ||
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
