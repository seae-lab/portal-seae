// lib/services/cadastro_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

import '../models/documento.dart';
import '../models/membro.dart';

class CadastroService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // CORREÇÃO: Getter da coleção de membros agora é público.
  CollectionReference get membrosCollection =>
      _firestore.collection('bases/base_cadastral/membros');

  DocumentReference get _departamentosDoc =>
      _firestore.doc('bases/base_departamentos');

  DocumentReference get _situacoesDoc =>
      _firestore.doc('bases/base_situacoes');

  DocumentReference get _contribuicoesDoc =>
      _firestore.doc('bases/base_ano_contribuicoes');

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
    return membrosCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Membro.fromFirestore(doc)).toList();
    });
  }

  Future<List<String>> getDepartamentos() async {
    try {
      final snapshot = await _departamentosDoc.get();
      if (!snapshot.exists || snapshot.data() == null) {
        return [];
      }

      final data = snapshot.data();
      if (data is Map<String, dynamic>) {
        return data.keys.toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, String>> getSituacoes() async {
    final snapshot = await _situacoesDoc.get();
    if (!snapshot.exists || snapshot.data() == null) return {};
    final data = snapshot.data() as Map<String, dynamic>;
    return data.map((key, value) => MapEntry(key, value.toString()));
  }

  Future<List<String>> getAnosContribuicao() async {
    final snapshot = await _contribuicoesDoc.get();
    if (!snapshot.exists || snapshot.data() == null) return [];
    final data = snapshot.data() as Map<String, dynamic>;
    final anos = List<dynamic>.from(data['contribuicoes'] ?? []);
    return anos.map((ano) => ano.toString()).toList();
  }

  Future<List<String>> getTiposMediunidade() async {
    final snapshot = await _tiposMediunidadeDoc.get();
    if (!snapshot.exists || snapshot.data() == null) return [];
    final data = snapshot.data() as Map<String, dynamic>;
    final mediunidades = List<dynamic>.from(data['mediunidades'] ?? []);
    return mediunidades.map((tipo) => tipo.toString()).toList();
  }

  bool isCpfValid(String cpf) {
    cpf = cpf.replaceAll(RegExp(r'[^0-9]'), '');
    if (cpf.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;

    List<int> digits = cpf.split('').map((d) => int.parse(d)).toList();

    int sum1 = 0;
    for (int i = 0; i < 9; i++) {
      sum1 += digits[i] * (10 - i);
    }
    int verifier1 = (sum1 * 10) % 11;
    if (verifier1 == 10) verifier1 = 0;
    if (verifier1 != digits[9]) return false;

    int sum2 = 0;
    for (int i = 0; i < 10; i++) {
      sum2 += digits[i] * (11 - i);
    }
    int verifier2 = (sum2 * 10) % 11;
    if (verifier2 == 10) verifier2 = 0;
    if (verifier2 != digits[10]) return false;

    return true;
  }

  Future<bool> isCpfUnique(String cpf, {String? currentMemberId}) async {
    if (cpf.isEmpty) return true;
    final query = membrosCollection.where('dados_pessoais.cpf', isEqualTo: cpf);
    final snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      return true;
    }
    if (currentMemberId != null && snapshot.docs.length == 1 && snapshot.docs.first.id == currentMemberId) {
      return true;
    }
    return false;
  }

  Future<bool> isEmailUnique(String email, {String? currentMemberId}) async {
    if (email.isEmpty) return true;
    final query = membrosCollection.where('dados_pessoais.e-mail', isEqualTo: email);
    final snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      return true;
    }
    if (currentMemberId != null && snapshot.docs.length == 1 && snapshot.docs.first.id == currentMemberId) {
      return true;
    }
    return false;
  }

  String _formatNameForUrl(String name) {
    // Remove caracteres especiais e substitui espaços por underscores
    final formattedName = name
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove caracteres especiais, exceto letras, números e espaços
        .replaceAll(' ', '_') // Substitui espaços por underscores
        .toLowerCase(); // Opcional: converte para minúsculas
    return formattedName;
  }

  Future<String> uploadProfileImage({
    required String memberId,
    required String memberName,
    required Uint8List fileBytes,
  }) async {
    try {
      final formattedName = _formatNameForUrl(memberName);
      final ref = _storage.ref('profile_images/$memberId\_$formattedName.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = ref.putData(fileBytes, metadata);
      final snapshot = await uploadTask.whenComplete(() => {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveMembro(Membro membro) {
    if (membro.id == null || membro.id!.isEmpty) {
      return membrosCollection.add(membro.toFirestore());
    } else {
      return membrosCollection.doc(membro.id).set(membro.toFirestore());
    }
  }

  Future<void> deleteMembro(String id) {
    return membrosCollection.doc(id).delete();
  }

  Future<Documento> uploadDocument({
    required String cpf,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final cleanCpf = cpf.replaceAll(RegExp(r'[^0-9]'), '');
      final fileExtension = fileName.split('.').last.toLowerCase();
      final ref = _storage.ref('documentos/$cleanCpf/$fileName');
      final metadata = SettableMetadata(contentType: 'application/$fileExtension');
      final uploadTask = ref.putData(fileBytes, metadata);
      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return Documento(nome: fileName, url: downloadUrl, tipo: fileExtension);
    } catch (e) {
      rethrow;
    }
  }
}