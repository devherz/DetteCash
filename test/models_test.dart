import 'package:flutter_test/flutter_test.dart';
import 'package:dettecash/models/commerce.dart';
import 'package:dettecash/models/client.dart';
import 'package:dettecash/models/transaction.dart';

void main() {
  group('Commerce Model Tests', () {
    test('Commerce serialization and deserialization', () {
      final commerce = Commerce(
        id: 1,
        nomCommerce: 'Boutique Horizon',
        telephoneCommerce: '+22670000000',
        adresseCommerce: 'Ouagadougou, Burkina Faso',
        logoPath: '/assets/logo.png',
      );

      final map = commerce.toMap();
      expect(map['id'], 1);
      expect(map['nom_commerce'], 'Boutique Horizon');
      expect(map['telephone_commerce'], '+22670000000');
      expect(map['adresse_commerce'], 'Ouagadougou, Burkina Faso');
      expect(map['logo_path'], '/assets/logo.png');

      final fromMapCommerce = Commerce.fromMap(map);
      expect(fromMapCommerce.id, commerce.id);
      expect(fromMapCommerce.nomCommerce, commerce.nomCommerce);
      expect(fromMapCommerce.telephoneCommerce, commerce.telephoneCommerce);
      expect(fromMapCommerce.adresseCommerce, commerce.adresseCommerce);
      expect(fromMapCommerce.logoPath, commerce.logoPath);
    });

    test('Commerce copyWith works correctly', () {
      final commerce = Commerce(
        id: 1,
        nomCommerce: 'Boutique Horizon',
        telephoneCommerce: '+22670000000',
      );

      final updated = commerce.copyWith(nomCommerce: 'Boutique Sahel');
      expect(updated.id, 1);
      expect(updated.nomCommerce, 'Boutique Sahel');
      expect(updated.telephoneCommerce, '+22670000000');
      expect(updated.adresseCommerce, isNull);
    });
  });

  group('Client Model Tests', () {
    test('Client serialization and deserialization', () {
      final date = DateTime.now();
      final client = Client(
        id: 42,
        commerceId: 1,
        nomComplet: 'Kaboré Moussa',
        telephone: '+22676000000',
        dateCreation: date,
      );

      final map = client.toMap();
      expect(map['id'], 42);
      expect(map['commerce_id'], 1);
      expect(map['nom_complet'], 'Kaboré Moussa');
      expect(map['telephone'], '+22676000000');
      // Date is stored as ISO 8601 string
      expect(map['date_creation'], date.toIso8601String());

      final fromMapClient = Client.fromMap(map);
      expect(fromMapClient.id, client.id);
      expect(fromMapClient.commerceId, client.commerceId);
      expect(fromMapClient.nomComplet, client.nomComplet);
      expect(fromMapClient.telephone, client.telephone);
      // Verify parsed dates are equivalent
      expect(fromMapClient.dateCreation.isAtSameMomentAs(client.dateCreation), true);
    });
  });

  group('Transaction Model Tests', () {
    test('Transaction DETTE type serialization and deserialization', () {
      final date = DateTime.now();
      final tx = TransactionModel(
        id: 99,
        clientId: 42,
        typeTransaction: TransactionType.dette,
        montant: 25000.50,
        dateTransaction: date,
        description: '1 sac de riz 25kg',
        photoPath: '/photos/riz.jpg',
        remainingAmount: 10000.0,
      );

      final map = tx.toMap();
      expect(map['id'], 99);
      expect(map['client_id'], 42);
      expect(map['type_transaction'], 'DETTE');
      expect(map['montant'], 25000.50);
      expect(map['date_transaction'], date.toIso8601String());
      expect(map['description'], '1 sac de riz 25kg');
      expect(map['photo_path'], '/photos/riz.jpg');
      expect(map['parent_transaction_id'], isNull);

      final fromMapTx = TransactionModel.fromMap({...map, 'remaining_amount': 10000.0});
      expect(fromMapTx.id, tx.id);
      expect(fromMapTx.clientId, tx.clientId);
      expect(fromMapTx.typeTransaction, TransactionType.dette);
      expect(fromMapTx.montant, tx.montant);
      expect(fromMapTx.dateTransaction.isAtSameMomentAs(tx.dateTransaction), true);
      expect(fromMapTx.description, tx.description);
      expect(fromMapTx.photoPath, tx.photoPath);
      expect(fromMapTx.parentTransactionId, isNull);
      expect(fromMapTx.remainingAmount, 10000.0);
    });

    test('Transaction PAIEMENT type serialization and deserialization with parent debt link', () {
      final date = DateTime.now();
      final tx = TransactionModel(
        id: 100,
        clientId: 42,
        typeTransaction: TransactionType.paiement,
        montant: 15000.0,
        dateTransaction: date,
        description: 'Règlement partiel',
        parentTransactionId: 99,
      );

      final map = tx.toMap();
      expect(map['type_transaction'], 'PAIEMENT');
      expect(map['photo_path'], isNull);
      expect(map['parent_transaction_id'], 99);

      final fromMapTx = TransactionModel.fromMap(map);
      expect(fromMapTx.typeTransaction, TransactionType.paiement);
      expect(fromMapTx.photoPath, isNull);
      expect(fromMapTx.parentTransactionId, 99);
      expect(fromMapTx.remainingAmount, isNull);
    });
  });
}
