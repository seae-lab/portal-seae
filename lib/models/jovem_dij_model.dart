// ARQUIVO COMPLETO: lib/models/jovem_dij_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class JovemDij {
  String? id;
  String nome;
  String? celularJovem;
  String? emailJovem;
  String ciclo;
  String? anotacoes;
  DateTime dataCadastro;
  String? dataNascimento;
  int? frequentaSeaeDesde;

  // Campos de Endereço
  String? cep;
  String? endereco;
  String? complemento;
  String? bairro;
  String? cidade;
  String? uf;

  // Campos de Filiação
  String? nomePai;
  String? celularPai;
  String? emailPai;
  String? nomeMae;
  String? celularMae;
  String? emailMae;

  JovemDij({
    this.id,
    required this.nome,
    this.celularJovem,
    this.emailJovem,
    required this.ciclo,
    this.anotacoes,
    required this.dataCadastro,
    this.dataNascimento,
    this.frequentaSeaeDesde,
    this.cep,
    this.endereco,
    this.complemento,
    this.bairro,
    this.cidade,
    this.uf,
    this.nomePai,
    this.celularPai,
    this.emailPai,
    this.nomeMae,
    this.celularMae,
    this.emailMae,
  });

  factory JovemDij.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return JovemDij(
      id: doc.id,
      nome: data['nome'] ?? '',
      celularJovem: data['celularJovem'],
      emailJovem: data['emailJovem'],
      ciclo: data['ciclo'] ?? 'Sem ciclo',
      anotacoes: data['anotacoes'],
      dataCadastro: (data['dataCadastro'] as Timestamp? ?? Timestamp.now()).toDate(),
      dataNascimento: data['dataNascimento'],
      frequentaSeaeDesde: data['frequentaSeaeDesde'],
      cep: data['cep'],
      endereco: data['endereco'],
      complemento: data['complemento'],
      bairro: data['bairro'],
      cidade: data['cidade'],
      uf: data['uf'],
      nomePai: data['nomePai'],
      celularPai: data['celularPai'],
      emailPai: data['emailPai'],
      nomeMae: data['nomeMae'],
      celularMae: data['celularMae'],
      emailMae: data['emailMae'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nome': nome,
      'celularJovem': celularJovem,
      'emailJovem': emailJovem,
      'ciclo': ciclo,
      'anotacoes': anotacoes,
      'dataCadastro': Timestamp.fromDate(dataCadastro),
      'dataNascimento': dataNascimento,
      'frequentaSeaeDesde': frequentaSeaeDesde,
      'cep': cep,
      'endereco': endereco,
      'complemento': complemento,
      'bairro': bairro,
      'cidade': cidade,
      'uf': uf,
      'nomePai': nomePai,
      'celularPai': celularPai,
      'emailPai': emailPai,
      'nomeMae': nomeMae,
      'celularMae': celularMae,
      'emailMae': emailMae,
    };
  }
}