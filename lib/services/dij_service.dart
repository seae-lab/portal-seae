// Conteúdo atualizado de ferrazt/pag-seae/pag-seae-f1ecfa12a567d6280aa4dbc6787d965af79b4a34/lib/services/dij_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/models/jovem_dij_model.dart';
import 'package:projetos/models/chamada_dij_model.dart';
import 'package:projetos/services/auth_service.dart';

import '../models/calendar_event_model.dart';

class DijService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'base_dij/base_jovens/jovens';
  final String _baseChamadaPath = 'base_dij/base_dij_chamada';
  final CollectionReference _eventsCollection =
  FirebaseFirestore.instance.collection('base_dij/dij_calendar/events');

  // Helper para obter o nome do documento do ciclo
  String _getCicloDocName(String ciclo) {
    // Transforma "Primeiro Ciclo" em "chamada_ciclo_primeiro_ciclo"
    return 'chamada_ciclo_${ciclo.replaceAll(' ', '_').toLowerCase()}';
  }

  // Helper para obter o ID do documento da chamada
  String _getDocId(DateTime data, String ciclo) {
    final cicloFormatado = ciclo.replaceAll(' ', '_');
    return "${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}_$cicloFormatado";
  }

  Stream<List<JovemDij>> getJovens({String? ciclo}) {
    Query query = _firestore.collection(_collectionPath).orderBy('nome');
    if (ciclo != null && ciclo.isNotEmpty) {
      query = query.where('ciclo', isEqualTo: ciclo);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => JovemDij.fromFirestore(doc)).toList();
    });
  }

  Future<void> addJovens(JovemDij aluno) {
    return _firestore.collection(_collectionPath).add(aluno.toFirestore());
  }

  Future<void> updateJovens(JovemDij aluno) {
    return _firestore
        .collection(_collectionPath)
        .doc(aluno.id)
        .update(aluno.toFirestore());
  }

  Future<void> deleteJovens(String alunoId) {
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

    final cicloDocName = _getCicloDocName(ciclo);
    final chamadaRef = _firestore.collection('$_baseChamadaPath/$cicloDocName');
    final docId = _getDocId(data, ciclo);

    return chamadaRef.doc(docId).set({
      'data': Timestamp.fromDate(data),
      'ciclo': ciclo,
      'presencas': presencas,
      'responsavelId': user.uid,
      'responsavelNome': user.displayName ?? user.email,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, bool>> getChamadaDoDia(DateTime data, String ciclo) async {
    final cicloDocName = _getCicloDocName(ciclo);
    final docId = _getDocId(data, ciclo);
    final doc = await _firestore.collection('$_baseChamadaPath/$cicloDocName').doc(docId).get();

    if (doc.exists && doc.data()?['presencas'] != null) {
      return Map<String, bool>.from(doc.data()!['presencas']);
    }
    return {};
  }

  Future<bool> checkChamadaExists(DateTime data, String ciclo) async {
    final cicloDocName = _getCicloDocName(ciclo);
    final docId = _getDocId(data, ciclo);
    final doc = await _firestore.collection('$_baseChamadaPath/$cicloDocName').doc(docId).get();
    return doc.exists;
  }

  Future<Map<String, int>> getJovensCountPorCiclo() async {
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
    final List<ChamadaDij> todasAsChamadas = [];

    final todosOsCiclos = [ 'Primeiro Ciclo', 'Segundo Ciclo', 'Terceiro Ciclo', 'Grupo de Pais', 'Pós Juventude' ];

    for (String ciclo in todosOsCiclos) {
      final cicloDocName = _getCicloDocName(ciclo);
      final snapshot = await _firestore
          .collection('$_baseChamadaPath/$cicloDocName')
          .where('data', isGreaterThanOrEqualTo: startOfDay)
          .where('data', isLessThanOrEqualTo: endOfDay)
          .get();

      for (var doc in snapshot.docs) {
        todasAsChamadas.add(ChamadaDij.fromFirestore(doc));
      }
    }

    return todasAsChamadas;
  }

  Future<List<DateTime>> getUltimasDatasDeChamada({int limit = 5}) async {
    final List<QuerySnapshot> snapshots = [];
    final todosOsCiclos = [ 'Primeiro Ciclo', 'Segundo Ciclo', 'Terceiro Ciclo', 'Grupo de Pais', 'Pós Juventude' ];

    for (String ciclo in todosOsCiclos) {
      final cicloDocName = _getCicloDocName(ciclo);
      final snapshot = await _firestore
          .collection('$_baseChamadaPath/$cicloDocName')
          .orderBy('data', descending: true)
          .limit(limit)
          .get();
      snapshots.add(snapshot);
    }

    final datas = snapshots
        .expand((snapshot) => snapshot.docs)
        .map((doc) {
      // --- CORREÇÃO APLICADA AQUI ---
      final docData = doc.data();
      if (docData != null && (docData as Map<String, dynamic>).containsKey('data')) {
        final timestamp = docData['data'] as Timestamp;
        final dt = timestamp.toDate();
        return DateTime(dt.year, dt.month, dt.day);
      }
      return null; // Retorna nulo se o campo 'data' não existir
    })
        .where((date) => date != null) // Filtra os nulos
        .map((date) => date!) // Converte de volta para uma lista não nula
        .toSet()
        .toList();

    datas.sort((a, b) => b.compareTo(a));

    return datas.take(limit).toList();
  }

  // Métodos do Calendário
  Stream<QuerySnapshot> getCalendarEvents() {
    return _eventsCollection.snapshots();
  }

  Future<void> addEvent(CalendarEventModel event) {
    return _eventsCollection.add(event.toFirestore());
  }

  Future<void> updateEvent(CalendarEventModel event) {
    return _eventsCollection.doc(event.id).update(event.toFirestore());
  }

  Future<void> deleteEvent(String eventId) {
    return _eventsCollection.doc(eventId).delete();
  }
}