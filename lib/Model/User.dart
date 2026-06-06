class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? role;
  final List<String>? skills;
  final String? bio;
  final String? speciality;
  final String? avatar;
  final String? companyName;
  final int? projectCount;
  final int? proposalCount;
  final int? wonCount;
  // ── CHAMPS JDOD ──────────────────────
  final String? location;
  final String? website;
  final String? linkedin;
  final String? github;
  final List<String>? languages;
  final double? hourlyRate;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.email,
    this.name,
    this.role,
    this.skills,
    this.bio,
    this.speciality,
    this.avatar,
    this.companyName,
    this.projectCount,
    this.proposalCount,
    this.wonCount,
    this.location,
    this.website,
    this.linkedin,
    this.github,
    this.languages,
    this.hourlyRate,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      email: json['email'] ?? '',
      name: json['name'],
      role: json['role'],
      skills: json['skills'] != null ? List<String>.from(json['skills']) : [],
      bio: json['bio'],
      speciality: json['speciality'],
      avatar: json['avatar'],
      companyName: json['companyName'],
      projectCount: _parseInt(json['projectCount']),
      proposalCount: _parseInt(json['proposalCount']),
      wonCount: _parseInt(json['wonCount']),
      // ── CHAMPS JDOD ──────────────────────
      location: json['location'],
      website: json['website'],
      linkedin: json['linkedin'],
      github: json['github'],
      languages: json['languages'] != null
          ? List<String>.from(json['languages'])
          : [],
      hourlyRate: json['hourlyRate'] != null
          ? double.tryParse(json['hourlyRate'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  String get displayName =>
      (name != null && name!.isNotEmpty) ? name! : email;

  List<dynamic>? get projects => null;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'role': role,
      'skills': skills,
      'bio': bio,
      'speciality': speciality,
      'avatar': avatar,
      'location': location,
      'website': website,
      'linkedin': linkedin,
      'github': github,
      'languages': languages,
      'hourlyRate': hourlyRate,
    };
  }
}