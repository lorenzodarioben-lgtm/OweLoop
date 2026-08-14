enum GroupRole {
  owner,
  admin,
  member;

  factory GroupRole.fromDatabase(Object? value) {
    return switch (value) {
      'owner' => GroupRole.owner,
      'admin' => GroupRole.admin,
      _ => GroupRole.member,
    };
  }

  String get label => switch (this) {
    GroupRole.owner => 'Owner',
    GroupRole.admin => 'Admin',
    GroupRole.member => 'Member',
  };

  bool get canAddGuests => this == GroupRole.owner || this == GroupRole.admin;
}

class AppGroup {
  const AppGroup({
    required this.id,
    required this.name,
    required this.currencyCode,
    required this.currentUserRole,
    this.createdAt,
    this.archivedAt,
  });

  final String id;
  final String name;
  final String currencyCode;
  final GroupRole currentUserRole;
  final DateTime? createdAt;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  factory AppGroup.fromMap(
    Map<String, dynamic> map, {
    required GroupRole currentUserRole,
  }) {
    final createdAt = map['created_at'];
    final archivedAt = map['archived_at'];
    return AppGroup(
      id: map['id'] as String,
      name: map['name'] as String,
      currencyCode: map['currency_code'] as String,
      currentUserRole: currentUserRole,
      createdAt: createdAt is String
          ? DateTime.tryParse(createdAt)
          : createdAt as DateTime?,
      archivedAt: archivedAt is String
          ? DateTime.tryParse(archivedAt)
          : archivedAt as DateTime?,
    );
  }

  factory AppGroup.fromMembershipMap(Map<String, dynamic> map) {
    final memberships = map['group_members'];
    final membership = switch (memberships) {
      [final Map<String, dynamic> value, ...] => value,
      [final Map value, ...] => Map<String, dynamic>.from(value),
      final Map<String, dynamic> value => value,
      final Map value => Map<String, dynamic>.from(value),
      _ => const <String, dynamic>{},
    };

    return AppGroup.fromMap(
      map,
      currentUserRole: GroupRole.fromDatabase(membership['role']),
    );
  }
}

class GroupMember {
  const GroupMember({
    required this.id,
    required this.displayName,
    required this.role,
    required this.userId,
    this.removedAt,
  });

  final String id;
  final String displayName;
  final GroupRole role;
  final String? userId;
  final DateTime? removedAt;

  bool get isGuest => userId == null;
  bool get isRemoved => removedAt != null;

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      id: map['id'] as String,
      displayName: map['display_name'] as String,
      role: GroupRole.fromDatabase(map['role']),
      userId: map['user_id'] as String?,
      removedAt: map['removed_at'] is String
          ? DateTime.tryParse(map['removed_at'] as String)
          : map['removed_at'] as DateTime?,
    );
  }
}

class GroupCreationInput {
  const GroupCreationInput({required this.name, required this.currencyCode});

  final String name;
  final String currencyCode;

  String get trimmedName => name.trim();
}

class GuestCreationInput {
  const GuestCreationInput({required this.displayName});

  final String displayName;

  String get trimmedDisplayName => displayName.trim();
}

class GroupRenameInput {
  const GroupRenameInput({required this.name});

  final String name;

  String get trimmedName => name.trim();
}
