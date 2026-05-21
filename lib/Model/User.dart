class UserModel {
  // --- ATTRIBUTS ---
  final String id;
  final String email;
  final String? name;       // Le '?' signifie que le nom peut être nul (ex: au moment de l'inscription)
  final String? role;       // Pour distinguer "client" ou "freelancer"
  final List<String>? skills; // Liste des compétences techniques (ex: Java, Design, Marketing)
  final String? bio;        // Description personnelle
  final String? speciality;
  final String? avatar;
  final String? companyName;
  final int? projectCount;
  final int? proposalCount;
  final int? wonCount;

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
  });

  // --- FACTORY : JSON -> OBJET DART ---
  // Transforme les données brutes de MongoDB en un objet utilisable par Flutter
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      // On accepte '_id' (MongoDB) ou 'id' pour éviter les erreurs de format
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      email: json['email'] ?? '',
      name: json['name'],
      role: json['role'],
      
      // GESTION DES LISTES : Le JSON envoie une liste dynamique, 
      // on la transforme proprement en List<String>
      skills: json['skills'] != null ? List<String>.from(json['skills']) : [],
      
      bio: json['bio'],
      speciality: json['speciality'],
      avatar: json['avatar'],
      companyName: json['companyName'],
      projectCount: _parseInt(json['projectCount']),
      proposalCount: _parseInt(json['proposalCount']),
      wonCount: _parseInt(json['wonCount']),
    );
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  // --- GETTERS (PROPRIÉTÉS CALCULÉES) ---
  
  // Si le nom est vide, on affiche l'email par défaut pour éviter un trou dans l'interface
  String get displayName => (name != null && name!.isNotEmpty) ? name! : email;

  List<dynamic>? get projects => null;

  // --- MÉTHODE : OBJET DART -> JSON ---
  // Utilisée par ton service pour mettre à jour le profil côté serveur Node.js
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'role': role,
      'skills': skills,
      'bio': bio,
      'speciality': speciality,
      'avatar':avatar,
    };
  }
}