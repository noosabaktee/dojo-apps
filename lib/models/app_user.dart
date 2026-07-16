class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.name,
    this.profilePhoto,
    this.intern,
    this.mentor,
    this.adminProfile,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: _asInt(json['id']),
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      name: json['name']?.toString() ?? json['email']?.toString() ?? 'User',
      profilePhoto: json['profile_photo']?.toString(),
      intern: _asMap(json['intern']),
      mentor: _asMap(json['mentor']),
      adminProfile: _asMap(json['admin_profile']),
    );
  }

  final int id;
  final String email;
  final String role;
  final String name;
  final String? profilePhoto;
  final Map<String, dynamic>? intern;
  final Map<String, dynamic>? mentor;
  final Map<String, dynamic>? adminProfile;

  bool get isIntern => role.toLowerCase() == 'intern';
  bool get isMentor => role.toLowerCase() == 'mentor';
  bool get isAdmin {
    final value = role.toLowerCase();
    return value == 'hrd' || value == 'headmaster';
  }

  String get roleLabel => switch (role.toLowerCase()) {
    'hrd' => 'Human Resources',
    'headmaster' => 'Headmaster',
    'mentor' => 'Mentor',
    _ => 'Intern',
  };

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return 'U';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
