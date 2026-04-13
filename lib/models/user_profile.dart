enum UserRole { guest, pilgrim, local, admin }

extension UserRoleDisplay on UserRole {
  String get label => switch (this) {
        UserRole.guest => 'Guest',
        UserRole.pilgrim => 'Pilgrim',
        UserRole.local => 'Local',
        UserRole.admin => 'Admin',
      };

  bool get canPost => this != UserRole.guest;
  bool get canPin => this == UserRole.admin || this == UserRole.local;
  bool get canDeleteAny => this == UserRole.admin;
}

class UserProfile {
  final String id;
  final String displayName;
  final int avatarSeed; // 0–9
  final UserRole role;
  final bool isDemo;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.avatarSeed,
    required this.role,
    this.isDemo = false,
    required this.createdAt,
  });

  UserProfile copyWith({String? displayName, int? avatarSeed, UserRole? role}) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      role: role ?? this.role,
      isDemo: isDemo,
      createdAt: createdAt,
    );
  }

  static UserRole roleFromString(String s) => UserRole.values.firstWhere(
        (e) => e.name == s,
        orElse: () => UserRole.guest,
      );
}
