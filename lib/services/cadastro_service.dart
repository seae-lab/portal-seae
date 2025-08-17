import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:projetos/screens/models/membro.dart';

class CadastroService {
  final CollectionReference _membrosCollection =
  FirebaseFirestore.instance.collection('base_cadastral');

  // CORREÇÃO: Adiciona a instância do Firebase Storage como uma variável da classe
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<Membro>> getMembros() {
    return _membrosCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Membro.fromFirestore(doc)).toList();
    });
  }

  /// Faz upload de uma imagem de perfil e retorna a URL de download.
  Future<String> uploadProfileImage({
    required String memberId,
    required Uint8List fileBytes,
  }) async {
    try {
      // Cria uma referência para o caminho do arquivo no Storage (ex: profile_images/2.jpg)
      final ref = _storage.ref('profile_images/$memberId.jpg');

      // Define os metadados do arquivo para otimização na web
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      // Faz o upload dos bytes do arquivo com os metadados
      final uploadTask = ref.putData(fileBytes, metadata);

      // Aguarda a conclusão do upload
      final snapshot = await uploadTask.whenComplete(() => {});

      // Pega a URL de download e a retorna
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Erro no upload da imagem: $e');
      rethrow; // Re-lança o erro para ser tratado na interface do usuário
    }
  }

  /// Salva (cria ou atualiza) um membro no Firestore.
  Future<void> saveMembro(Membro membro) {
    return _membrosCollection.doc(membro.id).set(membro.toFirestore());
  }

  /// Deleta um membro do Firestore.
  Future<void> deleteMembro(String id) {
    return _membrosCollection.doc(id).delete();
  }
}
