import 'package:cloud_firestore/cloud_firestore.dart';

class ChamadaDij {
  final String id;
  final String ciclo;
  final DateTime data;
  final String responsavelNome;
  final Map<String, bool> presencas; // Mapa de ID do jovem para presença

  ChamadaDij({
    required this.id,
    required this.ciclo,
    required this.data,
    required this.responsavelNome,
    required this.presencas,
  });

  factory ChamadaDij.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChamadaDij(
      id: doc.id,
      ciclo: data['ciclo'] ?? '',
      data: (data['data'] as Timestamp).toDate(),
      responsavelNome: data['responsavelNome'] ?? 'N/A',
      presencas: Map<String, bool>.from(data['presencas'] ?? {}),
    );
  }

  int get totalPresentes => presencas.values.where((presente) => presente).length;
  int get totalAlunos => presencas.length;
}