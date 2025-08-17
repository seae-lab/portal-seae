import 'package:cloud_firestore/cloud_firestore.dart';
import 'dados_pessoais.dart';

class Membro {
  String id;
  String nome;
  String foto;
  List<String> atividades;
  bool atualizacao;
  String atualizacaoCD;
  String atualizacaoCF;
  Map<String, bool> contribuicao;
  DadosPessoais dadosPessoais;
  String dataAprovacaoCD;
  String dataAtualizacao;
  String dataProposta;
  int frequentaSeaeDesde;
  bool frequentouOutrosCentros;
  bool listaContribuintes;
  bool mediunidadeOstensiva;
  bool novoSocio;
  int situacaoSEAE;
  String tipoMediunidade;
  bool transfAutomatica;

  Membro({
    required this.id,
    required this.nome,
    this.foto = '',
    // Torna os parâmetros de coleção anuláveis para forçar a inicialização correta
    List<String>? atividades,
    this.atualizacao = false,
    this.atualizacaoCD = '',
    this.atualizacaoCF = '',
    Map<String, bool>? contribuicao,
    required this.dadosPessoais,
    this.dataAprovacaoCD = '',
    this.dataAtualizacao = '',
    this.dataProposta = '',
    this.frequentaSeaeDesde = 0,
    this.frequentouOutrosCentros = false,
    this.listaContribuintes = false,
    this.mediunidadeOstensiva = false,
    this.novoSocio = false,
    this.situacaoSEAE = 0,
    this.tipoMediunidade = '',
    this.transfAutomatica = false,
  })  // Usa o corpo do construtor para garantir que as coleções sejam sempre modificáveis
      : this.atividades = atividades ?? [],
        this.contribuicao = contribuicao ?? {};

  /// Construtor de fábrica para criar uma instância de Membro a partir de um documento do Firestore.
  factory Membro.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Membro(
      id: doc.id,
      nome: data['nome'] ?? '',
      foto: data['foto'] ?? '',
      atividades: List<String>.from(data['atividade'] ?? []),
      atualizacao: data['atualizacao'] ?? false,
      atualizacaoCD: data['atualizacao_CD'] ?? '',
      atualizacaoCF: data['atualizacao_CF'] ?? '',
      contribuicao: Map<String, bool>.from(data['contribuicao'] ?? {}),
      dadosPessoais: DadosPessoais.fromMap(data['dados_pessoais'] ?? {}),
      dataAprovacaoCD: data['data_aprovacao_CD'] ?? '',
      dataAtualizacao: data['data_atualizacao'] ?? '',
      dataProposta: data['data_proposta'] ?? '',
      frequentaSeaeDesde: data['frequenta_seae_desde'] ?? 0,
      frequentouOutrosCentros: data['frequentou_outros_centros'] ?? false,
      listaContribuintes: data['lista_contribuintes'] ?? false,
      mediunidadeOstensiva: data['mediunidade_ostensiva'] ?? false,
      novoSocio: data['novo_socio'] ?? false,
      situacaoSEAE: data['situacao_SEAE'] ?? 0,
      tipoMediunidade: data['tipo_mediunidade'] ?? '',
      transfAutomatica: data['transf_automatica'] ?? false,
    );
  }

  /// Converte o objeto Membro de volta para um mapa, pronto para ser salvo no Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'nome': nome,
      'foto': foto,
      'atividade': atividades,
      'atualizacao': atualizacao,
      'atualizacao_CD': atualizacaoCD,
      'atualizacao_CF': atualizacaoCF,
      'contribuicao': contribuicao,
      'dados_pessoais': dadosPessoais.toMap(),
      'data_aprovacao_CD': dataAprovacaoCD,
      'data_atualizacao': dataAtualizacao,
      'data_proposta': dataProposta,
      'frequenta_seae_desde': frequentaSeaeDesde,
      'frequentou_outros_centros': frequentouOutrosCentros,
      'lista_contribuintes': listaContribuintes,
      'mediunidade_ostensiva': mediunidadeOstensiva,
      'novo_socio': novoSocio,
      'situacao_SEAE': situacaoSEAE,
      'tipo_mediunidade': tipoMediunidade,
      'transf_automatica': transfAutomatica,
    };
  }
}