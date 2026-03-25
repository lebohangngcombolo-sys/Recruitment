class TeamMember {
  final int id;
  final String name;
  final String role;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? avatar;

  TeamMember({
    required this.id,
    required this.name,
    required this.role,
    this.isOnline = false,
    this.lastSeen,
    this.avatar,
  });

  // Factory constructor for admin page usage
  factory TeamMember.fromAdminData({
    required int userId,
    required String name,
    required String role,
    bool isOnline = false,
    DateTime? lastSeen,
    String? avatar,
  }) {
    return TeamMember(
      id: userId,
      name: name,
      role: role,
      isOnline: isOnline,
      lastSeen: lastSeen,
      avatar: avatar,
    );
  }

  // Factory constructor for meeting dialog usage
  factory TeamMember.forMeeting({
    required int id,
    required String name,
    required String role,
    bool isOnline = false,
  }) {
    return TeamMember(
      id: id,
      name: name,
      role: role,
      isOnline: isOnline,
    );
  }
}
