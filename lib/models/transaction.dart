enum TransactionType {
  dette,
  paiement;

  String toDbValue() {
    switch (this) {
      case TransactionType.dette:
        return 'DETTE';
      case TransactionType.paiement:
        return 'PAIEMENT';
    }
  }

  static TransactionType fromDbValue(String value) {
    switch (value) {
      case 'DETTE':
        return TransactionType.dette;
      case 'PAIEMENT':
        return TransactionType.paiement;
      default:
        throw ArgumentError('Unknown transaction type: $value');
    }
  }
}

class TransactionModel {
  final int? id;
  final int clientId;
  final TransactionType typeTransaction;
  final double montant;
  final DateTime dateTransaction;
  final DateTime? dateEcheance;
  final String? description;
  final String? photoPath;
  final int? parentTransactionId;
  final double? remainingAmount; // Calculated field from db (optional)

  TransactionModel({
    this.id,
    required this.clientId,
    required this.typeTransaction,
    required this.montant,
    required this.dateTransaction,
    this.dateEcheance,
    this.description,
    this.photoPath,
    this.parentTransactionId,
    this.remainingAmount,
  });

  /// Check if a debt is overdue (past its due date with positive remaining amount)
  bool get isOverdue {
    if (typeTransaction != TransactionType.dette) return false;
    final double rem = remainingAmount ?? montant;
    if (rem <= 0) return false;
    if (dateEcheance == null) return false;
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final echeanceMidnight = DateTime(dateEcheance!.year, dateEcheance!.month, dateEcheance!.day);
    return echeanceMidnight.isBefore(todayMidnight);
  }

  /// Number of days overdue
  int get overdueDays {
    if (!isOverdue || dateEcheance == null) return 0;
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final echeanceMidnight = DateTime(dateEcheance!.year, dateEcheance!.month, dateEcheance!.day);
    return todayMidnight.difference(echeanceMidnight).inDays;
  }

  /// Convert a [TransactionModel] object into a Map.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'client_id': clientId,
      'type_transaction': typeTransaction.toDbValue(),
      'montant': montant,
      'date_transaction': dateTransaction.toIso8601String(),
      'date_echeance': dateEcheance?.toIso8601String(),
      'description': description,
      'photo_path': photoPath,
      'parent_transaction_id': parentTransactionId,
    };
  }

  /// Create a [TransactionModel] object from a Map.
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      clientId: map['client_id'] as int,
      typeTransaction: TransactionType.fromDbValue(map['type_transaction'] as String),
      montant: (map['montant'] as num).toDouble(),
      dateTransaction: DateTime.parse(map['date_transaction'] as String),
      dateEcheance: map['date_echeance'] != null ? DateTime.parse(map['date_echeance'] as String) : null,
      description: map['description'] as String?,
      photoPath: map['photo_path'] as String?,
      parentTransactionId: map['parent_transaction_id'] as int?,
      remainingAmount: map['remaining_amount'] != null ? (map['remaining_amount'] as num).toDouble() : null,
    );
  }

  /// Create a copy of [TransactionModel] with updated values.
  TransactionModel copyWith({
    int? id,
    int? clientId,
    TransactionType? typeTransaction,
    double? montant,
    DateTime? dateTransaction,
    DateTime? dateEcheance,
    String? description,
    String? photoPath,
    int? parentTransactionId,
    double? remainingAmount,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      typeTransaction: typeTransaction ?? this.typeTransaction,
      montant: montant ?? this.montant,
      dateTransaction: dateTransaction ?? this.dateTransaction,
      dateEcheance: dateEcheance ?? this.dateEcheance,
      description: description ?? this.description,
      photoPath: photoPath ?? this.photoPath,
      parentTransactionId: parentTransactionId ?? this.parentTransactionId,
      remainingAmount: remainingAmount ?? this.remainingAmount,
    );
  }

  @override
  String toString() {
    return 'TransactionModel(id: $id, clientId: $clientId, typeTransaction: $typeTransaction, montant: $montant, dateTransaction: $dateTransaction, dateEcheance: $dateEcheance, description: $description, photoPath: $photoPath, parentTransactionId: $parentTransactionId, remainingAmount: $remainingAmount)';
  }
}
