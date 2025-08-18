import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:projetos/screens/models/membro.dart';

class CadastroService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _membrosCollection =>
      _firestore.collection('bases/base_cadastral/membros');

  DocumentReference get _departamentosDoc =>
      _firestore.doc('bases/base_departamentos');

  DocumentReference get _situacoesDoc =>
      _firestore.doc('bases/base_situacoes');

  DocumentReference get _contribuicoesDoc =>
      _firestore.doc('bases/base_ano_contribuicoes');

  // NOVO: Referência para o documento de tipos de mediunidade
  DocumentReference get _tiposMediunidadeDoc =>
      _firestore.doc('bases/base_tipos_mediunidade');

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<Map<String, String>> fetchCep(String cep) async {
    final response = await http.get(Uri.parse('https://viacep.com.br/ws/$cep/json/'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['erro'] == true) {
        return {};
      }
      return {
        'endereco': data['logradouro'] ?? '',
        'bairro': data['bairro'] ?? '',
        'cidade': data['localidade'] ?? '',
        'uf': data['uf'] ?? '',
      };
    }
    return {};
  }

  Stream<List<Membro>> getMembros() {
    return _membrosCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Membro.fromFirestore(doc)).toList();
    });
  }

  Future<List<String>> getDepartamentos() async {
    final snapshot = await _departamentosDoc.get();
    if (!snapshot.exists || snapshot.data() == null) {
      return [];
    }
    final data = snapshot.data() as Map<String, dynamic>;
    return data.keys.toList();
  }

  Future<Map<String, String>> getSituacoes() async {
    final snapshot = await _situacoesDoc.get();
    if (!snapshot.exists || snapshot.data() == null) {
      return {};
    }
    final data = snapshot.data() as Map<String, dynamic>;
    return data.map((key, value) => MapEntry(key, value.toString()));
  }

  Future<List<String>> getAnosContribuicao() async {
    final snapshot = await _contribuicoesDoc.get();
    if (!snapshot.exists || snapshot.data() == null) {
      return [];
    }
    final data = snapshot.data() as Map<String, dynamic>;
    final anos = List<dynamic>.from(data['contribuicoes'] ?? []);
    return anos.map((ano) => ano.toString()).toList();
  }

  /// NOVO MÉTODO: Busca a lista de tipos de mediunidade.
  Future<List<String>> getTiposMediunidade() async {
    final snapshot = await _tiposMediunidadeDoc.get();
    if (!snapshot.exists || snapshot.data() == null) {
      return [];
    }
    final data = snapshot.data() as Map<String, dynamic>;
    final mediunidades = List<dynamic>.from(data['mediunidades'] ?? []);
    return mediunidades.map((tipo) => tipo.toString()).toList();
  }

  Future<String> uploadProfileImage({
    required String memberId,
    required Uint8List fileBytes,
  }) async {
    try {
      final ref = _storage.ref('profile_images/$memberId.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = ref.putData(fileBytes, metadata);
      final snapshot = await uploadTask.whenComplete(() => {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Erro no upload da imagem: $e');
      rethrow;
    }
  }

  Future<void> saveMembro(Membro membro) {
    return _membrosCollection.doc(membro.id).set(membro.toFirestore());
  }

  Future<void> deleteMembro(String id) {
    return _membrosCollection.doc(id).delete();
  }
}
