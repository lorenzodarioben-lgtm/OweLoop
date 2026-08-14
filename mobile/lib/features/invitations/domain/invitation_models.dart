class GroupInvitation {
  const GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.currencyCode,
    required this.inviterDisplayName,
    required this.expiresAt,
  });

  final String id;
  final String groupId;
  final String groupName;
  final String currencyCode;
  final String inviterDisplayName;
  final DateTime expiresAt;

  factory GroupInvitation.fromInboxMap(Map<String, dynamic> map) {
    return GroupInvitation(
      id: map['invitation_id'] as String,
      groupId: map['group_id'] as String,
      groupName: map['group_name'] as String,
      currencyCode: map['currency_code'] as String,
      inviterDisplayName: map['inviter_display_name'] as String,
      expiresAt: _dateTime(map['expires_at']),
    );
  }
}

class SentGroupInvitation {
  const SentGroupInvitation({
    required this.id,
    required this.recipientEmail,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String recipientEmail;
  final DateTime createdAt;
  final DateTime expiresAt;

  factory SentGroupInvitation.fromMap(Map<String, dynamic> map) {
    return SentGroupInvitation(
      id: map['invitation_id'] as String,
      recipientEmail: map['recipient_email'] as String,
      createdAt: _dateTime(map['created_at']),
      expiresAt: _dateTime(map['expires_at']),
    );
  }
}

class GroupInvitationInput {
  const GroupInvitationInput({required this.email});

  final String email;

  String get normalizedEmail => email.trim().toLowerCase();
}

DateTime _dateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw const InvitationRepositoryException('Invitation data is unavailable.');
}

class InvitationRepositoryException implements Exception {
  const InvitationRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
