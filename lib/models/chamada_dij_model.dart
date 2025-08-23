// NOVO ARQUIVO: lib/models/chamada_dij_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChamadaDij {
  final String id;
  final String ciclo;
  final DateTime data;
  final String responsavelNome;
  final Map<String, bool> alunos;

  ChamadaDij({
    required this.id,
    required this.ciclo,
    required this.data,
    required this.responsavelNome,
    required this.alunos,
  });

  factory ChamadaDij.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChamadaDij(
      id: doc.id,
      ciclo: data['ciclo'] ?? '',
      data: (data['data'] as Timestamp).toDate(),
      responsavelNome: data['responsavelNome'] ?? 'N/A',
      alunos: Map<String, bool>.from(data['alunos'] ?? {}),
    );
  }

  int get totalPresentes => alunos.values.where((presente) => presente).length;
  int get totalAlunos => alunos.length;
}