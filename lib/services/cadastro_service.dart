import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:projetos/utils/bairros_coordenadas.dart';
import '../models/documento.dart';
import '../models/membro.dart';

class CadastroService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  final Map<String, LatLng> _bairroCoordenadasCache = {};

  // Permissions
  CollectionReference get permissionsCollection => _firestore.collection('base_permissoes');

  Stream<List<QueryDocumentSnapshot>> getPermissions() {
    return permissionsCollection.snapshots().map((snapshot) => snapshot.docs);
  }

  Future<void> savePermission(String email, Map<String, dynamic> roles) {
    return permissionsCollection.doc(email).set(roles);
  }

  Future<void> deletePermission(String email) {
    return permissionsCollection.doc(email).delete();
  }

  // Departments (as a map)
  Future<Map<String, dynamic>> getDepartamentosMap() async {
    final snapshot = await _departamentosDoc.get();
    if (!snapshot.exists || snapshot.data() == null) return {};
    return snapshot.data() as Map<String, dynamic>;
  }

  Future<void> saveDepartamentosMap(Map<String, dynamic> departamentos) {
    return _departamentosDoc.set(departamentos);
  }

  // Situations (save method)
  Future<void> saveSituacoes(Map<String, String> situacoes) {
    final data = situacoes.map((key, value) => MapEntry(key, value as dynamic));
    return _situacoesDoc.set(data);
  }

  // Tipos Mediunidade (as a map)
  Future<Map<String, dynamic>> getTiposMediunidadeMap() async {
    final snapshot = await _tiposMediunidadeDoc.get();
    if (!snapshot.exists || snapshot.data() == null) return {};
    return snapshot.data() as Map<String, dynamic>;
  }

  Future<void> saveTiposMediunidadeMap(Map<String, dynamic> tipos) {
    return _tiposMediunidadeDoc.set(tipos);
  }

  Future<void> saveTiposMediunidadeList(List<String> tipos) {
    return _tiposMediunidadeDoc.set({'mediunidades': tipos});
  }

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

  Future<LatLng?> getCoordinatesFromBairro(String bairro) async {
    if (bairro.isEmpty) return null;
    final normalizedBairro = bairro.trim().toLowerCase();
    if (_bairroCoordenadasCache.containsKey(normalizedBairro)) {
      return _bairroCoordenadasCache[normalizedBairro];
    }
    final LatLng? localCoords = BAIRROS_COORDENADAS[normalizedBairro];
    if (localCoords != null) {
      _bairroCoordenadasCache[normalizedBairro] = localCoords;
      return localCoords;
    }
    return null;
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

  Future<String> uploadProfileImage({
    required String userId,
    required String userName,
    required Uint8List fileBytes,
  }) async {
    try {
      final safeUserName = userName.replaceAll(RegExp(r'\s+'), '_').toLowerCase();
      final ref = _storage.ref('profile_images/${userId}_$safeUserName.jpg');
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
    required String userId,
    required String userName,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final safeUserName = userName.replaceAll(RegExp(r'\s+'), '_').toLowerCase();
      final fileExtension = fileName.split('.').last.toLowerCase();
      final ref = _storage.ref('documentos/${userId}_$safeUserName/$fileName');
      final metadata = SettableMetadata(contentType: 'application/$fileExtension');
      final uploadTask = ref.putData(fileBytes, metadata);
      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return Documento(nome: fileName, url: downloadUrl, tipo: fileExtension);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteDocument(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (e) {
      if (e is FirebaseException && e.code == 'object-not-found') {
        // Arquivo não encontrado no Storage. Prossegue sem erro.
      } else {
        rethrow;
      }
    }
  }

  // --- FUNÇÕES DE ATUALIZAÇÃO E EXCLUSÃO EM CASCATA CORRIGIDAS ---

  Future<void> updateDepartmentInMembers(String oldSigla, String newSigla) async {
    final batch = _firestore.batch();
    final snapshot = await membrosCollection.get();

    for (var doc in snapshot.docs) {
      final membro = Membro.fromFirestore(doc);
      bool needsUpdate = false;
      final newAtividades = membro.atividades.map((atividade) {
        if (atividade == oldSigla || atividade.startsWith('$oldSigla/')) {
          needsUpdate = true;
          return newSigla + atividade.substring(oldSigla.length);
        }
        return atividade;
      }).toList();

      if (needsUpdate) {
        batch.update(doc.reference, {'atividade': newAtividades});
      }
    }
    await batch.commit();
  }

  Future<void> deleteDepartmentFromMembers(String sigla) async {
    final batch = _firestore.batch();
    final snapshot = await membrosCollection.get();

    for (var doc in snapshot.docs) {
      final membro = Membro.fromFirestore(doc);
      final initialCount = membro.atividades.length;
      final newAtividades = membro.atividades.where((atividade) {
        return !(atividade == sigla || atividade.startsWith('$sigla/'));
      }).toList();

      if (newAtividades.length < initialCount) {
        batch.update(doc.reference, {'atividade': newAtividades});
      }
    }
    await batch.commit();
  }

  Future<void> updateMediunidadeInMembers(String oldValue, String newValue) async {
    final batch = _firestore.batch();
    final snapshot = await membrosCollection.where('tipos_mediunidade', arrayContains: oldValue).get();

    for (var doc in snapshot.docs) {
      final membro = Membro.fromFirestore(doc);
      final newTipos = membro.tiposMediunidade.map((tipo) => tipo == oldValue ? newValue : tipo).toList();
      batch.update(doc.reference, {'tipos_mediunidade': newTipos});
    }
    await batch.commit();
  }

  Future<void> deleteMediunidadeFromMembers(String value) async {
    final batch = _firestore.batch();
    final snapshot = await membrosCollection.where('tipos_mediunidade', arrayContains: value).get();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'tipos_mediunidade': FieldValue.arrayRemove([value])});
    }
    await batch.commit();
  }
}