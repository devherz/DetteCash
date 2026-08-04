class Commerce {
  final int? id;
  final String nomCommerce;
  final String telephoneCommerce;
  final String? adresseCommerce;
  final String? logoPath;
  final String? customWhatsappTemplate;

  Commerce({
    this.id,
    required this.nomCommerce,
    required this.telephoneCommerce,
    this.adresseCommerce,
    this.logoPath,
    this.customWhatsappTemplate,
  });

  /// Default WhatsApp reminder message template
  static const String defaultWhatsappTemplate =
      "Bonjour {nom_client},\n\nVotre boutique {nom_commerce} vous rappelle un solde dû de {solde_du}.\nMerci de procéder au règlement via Mobile Money au {telephone_commerce}.\n\nCordialement !";

  /// Generates the reminder message for a client replacing template tags
  String buildWhatsappReminder({
    required String clientName,
    required String soldeDuFormatted,
  }) {
    final template = (customWhatsappTemplate != null && customWhatsappTemplate!.trim().isNotEmpty)
        ? customWhatsappTemplate!
        : defaultWhatsappTemplate;

    return template
        .replaceAll('{nom_client}', clientName)
        .replaceAll('{nom_commerce}', nomCommerce)
        .replaceAll('{solde_du}', soldeDuFormatted)
        .replaceAll('{telephone_commerce}', telephoneCommerce);
  }

  /// Convert a [Commerce] object into a Map.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nom_commerce': nomCommerce,
      'telephone_commerce': telephoneCommerce,
      'adresse_commerce': adresseCommerce,
      'logo_path': logoPath,
      'custom_whatsapp_template': customWhatsappTemplate,
    };
  }

  /// Create a [Commerce] object from a Map.
  factory Commerce.fromMap(Map<String, dynamic> map) {
    return Commerce(
      id: map['id'] as int?,
      nomCommerce: map['nom_commerce'] as String,
      telephoneCommerce: map['telephone_commerce'] as String,
      adresseCommerce: map['adresse_commerce'] as String?,
      logoPath: map['logo_path'] as String?,
      customWhatsappTemplate: map['custom_whatsapp_template'] as String?,
    );
  }

  /// Create a copy of [Commerce] with updated values.
  Commerce copyWith({
    int? id,
    String? nomCommerce,
    String? telephoneCommerce,
    String? adresseCommerce,
    String? logoPath,
    String? customWhatsappTemplate,
  }) {
    return Commerce(
      id: id ?? this.id,
      nomCommerce: nomCommerce ?? this.nomCommerce,
      telephoneCommerce: telephoneCommerce ?? this.telephoneCommerce,
      adresseCommerce: adresseCommerce ?? this.adresseCommerce,
      logoPath: logoPath ?? this.logoPath,
      customWhatsappTemplate: customWhatsappTemplate ?? this.customWhatsappTemplate,
    );
  }

  @override
  String toString() {
    return 'Commerce(id: $id, nomCommerce: $nomCommerce, telephoneCommerce: $telephoneCommerce, adresseCommerce: $adresseCommerce, logoPath: $logoPath, customWhatsappTemplate: $customWhatsappTemplate)';
  }
}
