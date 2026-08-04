class UserModel {
  final int? id;
  final String nom;
  final String telephone;
  final String motDePasse; // 4-digit PIN code
  final String role; // 'ADMIN' or 'USER'

  UserModel({
    this.id,
    required this.nom,
    required this.telephone,
    required this.motDePasse,
    required this.role,
  });

  /// Convert a [UserModel] object into a Map.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nom': nom,
      'telephone': telephone,
      'mot_de_passe': motDePasse,
      'role': role,
    };
  }

  /// Create a [UserModel] object from a Map.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      telephone: map['telephone'] as String,
      motDePasse: map['mot_de_passe'] as String,
      role: map['role'] as String,
    );
  }

  /// Create a copy of [UserModel] with updated values.
  UserModel copyWith({
    int? id,
    String? nom,
    String? telephone,
    String? motDePasse,
    String? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      telephone: telephone ?? this.telephone,
      motDePasse: motDePasse ?? this.motDePasse,
      role: role ?? this.role,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, nom: $nom, telephone: $telephone, role: $role)';
  }
}
