class Client {
  final int? id;
  final int commerceId;
  final String nomComplet;
  final String telephone;
  final DateTime dateCreation;

  Client({
    this.id,
    required this.commerceId,
    required this.nomComplet,
    required this.telephone,
    required this.dateCreation,
  });

  /// Convert a [Client] object into a Map.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'commerce_id': commerceId,
      'nom_complet': nomComplet,
      'telephone': telephone,
      'date_creation': dateCreation.toIso8601String(),
    };
  }

  /// Create a [Client] object from a Map.
  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as int?,
      commerceId: map['commerce_id'] as int,
      nomComplet: map['nom_complet'] as String,
      telephone: map['telephone'] as String,
      dateCreation: DateTime.parse(map['date_creation'] as String),
    );
  }

  /// Create a copy of [Client] with updated values.
  Client copyWith({
    int? id,
    int? commerceId,
    String? nomComplet,
    String? telephone,
    DateTime? dateCreation,
  }) {
    return Client(
      id: id ?? this.id,
      commerceId: commerceId ?? this.commerceId,
      nomComplet: nomComplet ?? this.nomComplet,
      telephone: telephone ?? this.telephone,
      dateCreation: dateCreation ?? this.dateCreation,
    );
  }

  @override
  String toString() {
    return 'Client(id: $id, commerceId: $commerceId, nomComplet: $nomComplet, telephone: $telephone, dateCreation: $dateCreation)';
  }
}
