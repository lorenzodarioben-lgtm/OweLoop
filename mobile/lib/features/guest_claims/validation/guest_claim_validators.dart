import '../../invitations/validation/invitation_validators.dart';

class GuestClaimValidators {
  const GuestClaimValidators._();

  static String? email(String? value) => InvitationValidators.email(value);
}
