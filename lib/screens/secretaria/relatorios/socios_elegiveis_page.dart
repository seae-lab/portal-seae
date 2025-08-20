// lib/screens/secretaria/relatorios/socios_elegiveis_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:flutter/services.dart';

import '../../../models/membro.dart';
import '../../../services/cadastro_service.dart';

class SociosElegiveisPage extends StatefulWidget {
  const SociosElegiveisPage({super.key});

  @override
  State<SociosElegiveisPage> createState() => _SociosElegiveisPageState();
}

class _SociosElegiveisPageState extends State<SociosElegiveisPage> {
  final CadastroService _cadastroService = Modular.get<CadastroService>();
  List<Membro> _membrosElegiveis = [];
  bool _isLoading = true;
  String? _error;

  static const int idSituacaoEfetivo = 4;
  static const int anosMinimosAssociado = 4;
  static const int mesesContribuicaoIninterrupta = 48;

  final Map<String, String> _meses = {
    '01': 'janeiro',
    '02': 'fevereiro',
    '03': 'marco',
    '04': 'abril',
    '05': 'maio',
    '06': 'junho',
    '07': 'julho',
    '08': 'agosto',
    '09': 'setembro',
    '10': 'outubro',
    '11': 'novembro',
    '12': 'dezembro',
  };

  final Map<String, String> _availableFields = {
    'nome': 'Nome',
    'cpf': 'CPF',
    'data_proposta': 'Data de Proposta',
    'ultima_atualizacao': 'Última Atualização',
    'departamento': 'Departamento',
    'situacao_nome': 'Situação',
  };
  Set<String> _activeColumns = {'nome', 'cpf', 'departamento', 'situacao_nome', 'ultima_atualizacao'};
  Map<String, String> _situacoesMap = {};


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _loadSituacoes();
    await _apurarElegiveis();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSituacoes() async {
    try {
      _situacoesMap = await _cadastroService.getSituacoes();
    } catch (e) {
      if(mounted) {
        setState(() {
          _error = 'Erro ao carregar as situações: $e';
        });
      }
    }
  }

  DateTime? _parseDate(String dateStr) {
    try {
      return DateFormat('dd/MM/yyyy').parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  Future<void> _apurarElegiveis() async {
    try {
      final todosMembros = await _cadastroService.getMembros().first;
      final elegiveis = <Membro>[];
      final hoje = DateTime.now();

      for (final membro in todosMembros) {
        if (membro.situacaoSEAE != idSituacaoEfetivo) continue;

        final dataAssociacao = _parseDate(membro.dataProposta);
        if (dataAssociacao == null) continue;
        final anosComoAssociado = hoje.difference(dataAssociacao).inDays / 365.25;
        if (anosComoAssociado < anosMinimosAssociado) continue;

        if (!_temContribuicaoIninterrupta(membro, mesesContribuicaoIninterrupta)) continue;

        if (membro.atividades.isEmpty) continue;

        elegiveis.add(membro);
      }

      if (mounted) {
        setState(() {
          _membrosElegiveis = elegiveis;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao buscar membros: $e';
        });
      }
    }
  }

  bool _temContribuicaoIninterrupta(Membro membro, int totalMeses) {
    final hoje = DateTime.now();
    for (int i = 0; i < totalMeses; i++) {
      final dataAlvo = DateTime(hoje.year, hoje.month - i, 1);
      final ano = dataAlvo.year.toString();
      final mes = _meses[dataAlvo.month.toString().padLeft(2, '0')];

      final contribuicaoAno = membro.contribuicao[ano] as Map<String, dynamic>?;
      if (contribuicaoAno == null) return false;

      final mesesData = contribuicaoAno['meses'] as Map<String, dynamic>?;
      if (mesesData == null || mesesData[mes] != true) return false;
    }
    return true;
  }

  String _getCellValue(Membro membro, String field) {
    switch (field) {
      case 'nome':
        return membro.nome;
      case 'cpf':
        return membro.dadosPessoais.cpf;
      case 'data_proposta':
        return membro.dataProposta;
      case 'ultima_atualizacao':
        return membro.dataAtualizacao;
      case 'departamento':
        return membro.atividades.join(', ');
      case 'situacao_nome':
        return _situacoesMap[membro.situacaoSEAE.toString()] ?? 'N/A';
      default:
        return '';
    }
  }

  Future<void> _gerarPdf() async {
    final pdf = pw.Document();
    final now = DateFormat("dd/MM/yyyy 'às' HH:mm").format(DateTime.now());

    final logoImage = await rootBundle.load('assets/images/logo_SEAE_azul.png');
    final image = pw.MemoryImage(logoImage.buffer.asUint8List());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader(now, image),
        build: (context) => [
          _buildContentTable(context),
        ],
        footer: (context) => _buildFooter(context),
      ),
    );

    final bytes = await pdf.save();

    if (kIsWeb) {
      final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'application/pdf'));
      final url = web.URL.createObjectURL(blob);
      web.window.open(url, '_blank');
      web.URL.revokeObjectURL(url);
    } else {
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sócios Elegíveis a Conselheiro'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_membrosElegiveis.isEmpty) {
      return const Center(child: Text('Nenhum sócio elegível encontrado com os critérios atuais.'));
    }
    return Column(
      children: [
        _buildColumnSelection(),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: DataTable(
                  columns: _activeColumns.map((field) {
                    return DataColumn(label: Text(_availableFields[field] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)));
                  }).toList(),
                  rows: _membrosElegiveis.map((membro) {
                    return DataRow(cells: _activeColumns.map((field) {
                      return DataCell(Text(_getCellValue(membro, field)));
                    }).toList());
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColumnSelection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selecionar Colunas', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _availableFields.entries.map((entry) {
              final field = entry.key;
              final label = entry.value;
              final isSelected = _activeColumns.contains(field);
              final isDefault = field == 'nome' || field == 'cpf';

              return FilterChip(
                label: Text(label),
                selected: isSelected,
                onSelected: isDefault
                    ? null
                    : (bool selected) {
                  setState(() {
                    if (selected) {
                      _activeColumns.add(field);
                    } else {
                      _activeColumns.remove(field);
                    }
                  });
                },
                checkmarkColor: Colors.white,
                selectedColor: Theme.of(context).primaryColor,
                backgroundColor: Colors.grey.shade200,
                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildHeader(String now, pw.MemoryImage logo) {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(bottom: 20.0),
      child: pw.Column(
        children: [
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(logo, width: 50, height: 50),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Relação de Sócios Efetivos Elegíveis a Conselheiro', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.SizedBox(height: 5),
                    pw.Text('Gerado em: $now', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.SizedBox(width: 50),
              ]
          ),
          pw.Divider(color: PdfColors.grey),
        ],
      ),
    );
  }

  pw.Widget _buildContentTable(pw.Context context) {
    final tableHeaders = _activeColumns.map((field) => _availableFields[field] ?? 'N/A').toList();
    final tableData = _membrosElegiveis.map((membro) {
      return _activeColumns.map((field) => _getCellValue(membro, field)).toList();
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: tableHeaders,
      data: tableData,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 10),
      border: pw.TableBorder.all(),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10.0),
      child: pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
      ),
    );
  }
}