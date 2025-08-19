import 'package:cloud_firestore/cloud_firestore.dart';
import 'dados_pessoais.dart';

class Membro {
  String? id;
  String nome;
  String foto;
  List<String> atividades;
  bool atualizacao;
  String atualizacaoCD;
  String atualizacaoCF;
  // MODIFICADO: A estrutura agora é um mapa dinâmico para suportar o status 'quitado'
  Map<String, dynamic> contribuicao;
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
  List<String> tiposMediunidade;
  bool transfAutomatica;

  Membro({
    this.id,
    required this.nome,
    this.foto = '',
    List<String>? atividades,
    this.atualizacao = false,
    this.atualizacaoCD = '',
    this.atualizacaoCF = '',
    Map<String, dynamic>? contribuicao,
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
    List<String>? tiposMediunidade,
    this.transfAutomatica = false,
  })  : atividades = atividades ?? [],
        contribuicao = contribuicao ?? {},
        tiposMediunidade = tiposMediunidade ?? [];

  factory Membro.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final rawContribuicao = data['contribuicao'] as Map<String, dynamic>? ?? {};
    final Map<String, dynamic> contribuicaoMap = {};
    const meses = ['janeiro', 'fevereiro', 'marco', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];

    rawContribuicao.forEach((year, value) {
      if (value is Map) {
        // Novo formato: {'2024': {'quitado': bool, 'meses': { ... }}}
        contribuicaoMap[year] = {
          'quitado': value['quitado'] ?? false,
          'meses': Map<String, bool>.from(value['meses']?.cast<String, bool>() ?? {}),
        };
      } else if (value is bool) {
        // Formato antigo: {'2024': true} -> converte para o novo formato
        contribuicaoMap[year] = {
          'quitado': value,
          'meses': { for (var m in meses) m: value },
        };
      }
    });

    return Membro(
      id: doc.id,
      nome: data['nome'] ?? '',
      foto: data['foto'] ?? '',
      atividades: List<String>.from(data['atividade'] ?? []),
      atualizacao: data['atualizacao'] ?? false,
      atualizacaoCD: data['atualizacao_CD'] ?? '',
      atualizacaoCF: data['atualizacao_CF'] ?? '',
      contribuicao: contribuicaoMap,
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
      tiposMediunidade: List<String>.from(data['tipos_mediunidade'] ?? []),
      transfAutomatica: data['transf_automatica'] ?? false,
    );
  }

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
      'tipos_mediunidade': tiposMediunidade,
      'transf_automatica': transfAutomatica,
    };
  }
}
