import 'package:flutter_test/flutter_test.dart';
import 'package:dettecash/models/user.dart';

void main() {
  group('UserModel Tests', () {
    test('UserModel serialization and deserialization', () {
      final user = UserModel(
        id: 1,
        nom: 'Test Admin',
        telephone: '00000000',
        motDePasse: '1234',
        role: 'ADMIN',
      );

      final map = user.toMap();
      expect(map['id'], 1);
      expect(map['nom'], 'Test Admin');
      expect(map['telephone'], '00000000');
      expect(map['mot_de_passe'], '1234');
      expect(map['role'], 'ADMIN');

      final fromMapUser = UserModel.fromMap(map);
      expect(fromMapUser.id, user.id);
      expect(fromMapUser.nom, user.nom);
      expect(fromMapUser.telephone, user.telephone);
      expect(fromMapUser.motDePasse, user.motDePasse);
      expect(fromMapUser.role, user.role);
    });

    test('UserModel copyWith works correctly', () {
      final user = UserModel(
        id: 1,
        nom: 'Test Admin',
        telephone: '00000000',
        motDePasse: '1234',
        role: 'ADMIN',
      );

      final updated = user.copyWith(motDePasse: '9999');
      expect(updated.id, 1);
      expect(updated.nom, 'Test Admin');
      expect(updated.motDePasse, '9999');
      expect(updated.role, 'ADMIN');
    });
  });
}
