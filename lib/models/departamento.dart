import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa um departamento vindo da coleção 'base_departamentos'.
class Departamento {
  final String id; // O ID do documento (ex: "DIJ")
  final String descricao; // O campo "descricao" (ex: "Departamento da Infância e Juventude")

  Departamento({required this.id, required this.descricao});

  /// Cria uma instância de Departamento a partir de um documento do Firestore.
  factory Departamento.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Departamento(
      id: doc.id,
      descricao: data['descricao'] ?? '',
    );
  }
}
