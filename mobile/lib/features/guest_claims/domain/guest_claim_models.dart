class GuestClaimRequest {
  const GuestClaimRequest({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.currencyCode,
    required this.guestMemberId,
    required this.guestDisplayName,
    required this.initiatedByDisplayName,
    required this.expiresAt,
  });

  final String id;
  final String groupId;
  final String groupName;
  final String currencyCode;
  final String guestMemberId;
  final String guestDisplayName;
  final String initiatedByDisplayName;
  final DateTime expiresAt;

  factory GuestClaimRequest.fromInboxMap(Map<String, dynamic> map) {
    return GuestClaimRequest(
      id: map['claim_request_id'] as String,
      groupId: map['group_id'] as String,
      groupName: map['group_name'] as String,
      currencyCode: map['currency_code'] as String,
      guestMemberId: map['guest_member_id'] as String,
      guestDisplayName: map['guest_display_name'] as String,
      initiatedByDisplayName: map['initiated_by_display_name'] as String,
      expiresAt: _dateTime(map['expires_at']),
    );
  }
}

class SentGuestClaimRequest {
  const SentGuestClaimRequest({
    required this.id,
    required this.guestMemberId,
    required this.guestDisplayName,
    required this.recipientEmail,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String guestMemberId;
  final String guestDisplayName;
  final String recipientEmail;
  final DateTime createdAt;
  final DateTime expiresAt;

  factory SentGuestClaimRequest.fromMap(Map<String, dynamic> map) {
    return SentGuestClaimRequest(
      id: map['claim_request_id'] as String,
      guestMemberId: map['guest_member_id'] as String,
      guestDisplayName: map['guest_display_name'] as String,
      recipientEmail: map['recipient_email'] as String,
      createdAt: _dateTime(map['created_at']),
      expiresAt: _dateTime(map['expires_at']),
    );
  }
}

class GuestClaimInput {
  const GuestClaimInput({required this.email});

  final String email;

  String get normalizedEmail => email.trim().toLowerCase();
}

DateTime _dateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw const GuestClaimRepositoryException('Guest claim data is unavailable.');
}

class GuestClaimRepositoryException implements Exception {
  const GuestClaimRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
