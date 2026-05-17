class ProjectModel {
  // --- DÉFINITION DES ATTRIBUTS ---
  final String id;
  final String title;
  final String description;
  final int budget;
  final List<String> skillsRequired; // Liste des compétences (ex: ["Flutter", "Node.js"])
  final dynamic clientId;             // ID du client qui a posté le projet
  final String status;               // État du projet (ex: "open", "in_progress", "completed")
  final DateTime createdAt;          // Date de création convertie en objet Date Dart

  // Constructeur : Oblige à donner toutes les infos pour créer un projet
  ProjectModel({
    required this.id,
    required this.title,
    required this.description,
    required this.budget,
    required this.skillsRequired,
    required this.clientId,
    required this.status,
    required this.createdAt,
  });

  // --- FACTORY : LA DÉSERIALISATION (JSON -> OBJET DART) ---
  // Cette méthode prend le JSON reçu du serveur et crée un objet ProjectModel
  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      // MongoDB utilise '_id', on le récupère et on met une valeur vide par défaut si nul (?? '')
      id: json['_id'] ?? '',
      title: json['title'] ?? 'Sans titre',
      description: json['description'] ?? '',
      
      // Conversion sécurisée : on force le nombre en entier (int)
      budget: (json['budget'] ?? 0).toInt(),
      
      // Conversion de List<dynamic> (JSON) vers List<String> (Dart)
      skillsRequired: List<String>.from(json['skillsRequired'] ?? []),
      
      // Gestion de la relation : si clientId est un objet (Populate), on prend son _id, sinon on prend la String
      clientId: json['clientId'] is Map 
          ? json['clientId']['_id']?.toString() ?? ''
          : (json['clientId']?.toString() ?? '',),
          
      status: json['status'] ?? 'open',
      
      // Transformation de la chaîne de caractères (String) en objet DateTime manipulable par Flutter
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }

  // --- METHOD : LA SERIALISATION (OBJET DART -> JSON) ---
  // Utile quand tu veux envoyer un nouveau projet au serveur via une requête POST
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'budget': budget,
      'skillsRequired': skillsRequired,
      'clientId': clientId,
      'status': status,
      // On ne met pas l'id ni la date car c'est MongoDB qui les génère automatiquement
    };
  }
}