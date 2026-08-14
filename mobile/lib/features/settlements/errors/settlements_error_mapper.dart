import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/settlements_repository.dart';

class SettlementsErrorMapper {
  const SettlementsErrorMapper._();

  static String messageFor(Object error) {
    final message = switch (error) {
      SettlementsRepositoryException error => error.message,
      PostgrestException error => error.message,
      _ => '',
    };
    final lowerCase = message.toLowerCase();
    if (lowerCase.contains('different active group members')) {
      return 'Choose two different active group members.';
    }
    if (lowerCase.contains('amount must be greater than zero')) {
      return 'Enter a valid positive amount.';
    }
    if (lowerCase.contains('date cannot be in the future')) {
      return 'A settlement can only be dated today or earlier.';
    }
    if (lowerCase.contains('archived')) {
      return 'This group is archived and cannot be changed.';
    }
    if (lowerCase.contains('unavailable')) {
      return 'This group or settlement is unavailable.';
    }
    if (lowerCase.contains('already voided')) {
      return 'This settlement has already been voided.';
    }
    if (lowerCase.contains('active settlement manager')) {
      return 'You do not have permission to void this settlement.';
    }
    return 'Something went wrong. Please try again.';
  }
}
