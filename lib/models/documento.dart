class Documento {
  final String nome;
  final String url;
  final String tipo; // ex: 'pdf', 'png', 'jpeg'

  Documento({
    required this.nome,
    required this.url,
    required this.tipo,
  });

  factory Documento.fromMap(Map<String, dynamic> data) {
    return Documento(
      nome: data['nome'] ?? '',
      url: data['url'] ?? '',
      tipo: data['tipo'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'url': url,
      'tipo': tipo,
    };
  }
}