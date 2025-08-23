// ARQUIVO COMPLETO: lib/services/dij_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/models/jovem_dij_model.dart';
import 'package:projetos/models/chamada_dij_model.dart';
import 'package:projetos/services/auth_service.dart';

class DijService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'base_dij';
  final String _chamadaCollectionPath = 'base_dij_chamada';

  String _getDocId(DateTime data, String ciclo) {
    final cicloFormatado = ciclo.replaceAll(' ', '_');
    return "${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}_$cicloFormatado";
  }

  Stream<List<JovemDij>> getAlunos({String? ciclo}) {
    Query query = _firestore.collection(_collectionPath).orderBy('nome');
    if (ciclo != null && ciclo.isNotEmpty) {
      query = query.where('ciclo', isEqualTo: ciclo);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => JovemDij.fromFirestore(doc)).toList();
    });
  }

  Future<void> addAluno(JovemDij aluno) {
    return _firestore.collection(_collectionPath).add(aluno.toFirestore());
  }

  Future<void> updateAluno(JovemDij aluno) {
    return _firestore
        .collection(_collectionPath)
        .doc(aluno.id)
        .update(aluno.toFirestore());
  }

  Future<void> deleteAluno(String alunoId) {
    return _firestore.collection(_collectionPath).doc(alunoId).delete();
  }

  Future<void> salvarChamada({
    required DateTime data,
    required String ciclo,
    required Map<String, bool> presencas,
  }) async {
    final AuthService authService = Modular.get<AuthService>();
    final user = authService.currentUser;
    if (user == null) return;

    final chamadaRef = _firestore.collection(_chamadaCollectionPath);
    final docId = _getDocId(data, ciclo);

    return chamadaRef.doc(docId).set({
      'data': Timestamp.fromDate(data),
      'ciclo': ciclo,
      'alunos': presencas,
      'responsavelId': user.uid,
      'responsavelNome': user.displayName ?? user.email,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, bool>> getChamadaDoDia(DateTime data, String ciclo) async {
    final docId = _getDocId(data, ciclo);
    final doc = await _firestore.collection(_chamadaCollectionPath).doc(docId).get();
    if (doc.exists && doc.data()?['alunos'] != null) {
      return Map<String, bool>.from(doc.data()!['alunos']);
    }
    return {};
  }

  Future<bool> checkChamadaExists(DateTime data, String ciclo) async {
    final docId = _getDocId(data, ciclo);
    final doc = await _firestore.collection(_chamadaCollectionPath).doc(docId).get();
    return doc.exists;
  }

  Future<Map<String, int>> getAlunosCountPorCiclo() async {
    final snapshot = await _firestore.collection(_collectionPath).get();
    final counts = <String, int>{};
    for (var doc in snapshot.docs) {
      final ciclo = doc.data()['ciclo'] as String?;
      if (ciclo != null) {
        counts.update(ciclo, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  Future<List<ChamadaDij>> getChamadasPorData(DateTime data) async {
    final startOfDay = DateTime(data.year, data.month, data.day);
    final endOfDay = DateTime(data.year, data.month, data.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection(_chamadaCollectionPath)
        .where('data', isGreaterThanOrEqualTo: startOfDay)
        .where('data', isLessThanOrEqualTo: endOfDay)
        .get();

    return snapshot.docs.map((doc) => ChamadaDij.fromFirestore(doc)).toList();
  }

  Future<List<DateTime>> getUltimasDatasDeChamada({int limit = 5}) async {
    final snapshot = await _firestore
        .collection(_chamadaCollectionPath)
        .orderBy('data', descending: true)
        .limit(limit)
        .get();

    final datas = snapshot.docs.map((doc) {
      final timestamp = doc.data()['data'] as Timestamp;
      final dt = timestamp.toDate();
      return DateTime(dt.year, dt.month, dt.day);
    }).toSet().toList();

    return datas;
  }
}