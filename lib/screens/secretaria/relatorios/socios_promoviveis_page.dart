// lib/screens/secretaria/relatorios/socios_promoviveis_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:projetos/widgets/loading_overlay.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:flutter/services.dart';

import '../../../models/membro.dart';
import '../../../services/cadastro_service.dart';

class SociosPromoviveisPage extends StatefulWidget {
  const SociosPromoviveisPage({super.key});

  @override
  State<SociosPromoviveisPage> createState() => _SociosPromoviveisPageState();
}

class _SociosPromoviveisPageState extends State<SociosPromoviveisPage> {
  final CadastroService _cadastroService = Modular.get<CadastroService>();
  List<Membro> _membrosPromoviveis = [];
  bool _isLoading = true;
  String? _error;
  bool _isGeneratingPdf = false;


  static const int idSituacaoColaborador = 3;
  static const int mesesContribuicaoIninterrupta = 12;

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
    'situacao_nome': 'Situação',
  };
  Set<String> _activeColumns = {'nome', 'cpf', 'situacao_nome', 'ultima_atualizacao'};
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
    await _apurarPromoviveis();
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

  Future<void> _apurarPromoviveis() async {
    try {
      final todosMembros = await _cadastroService.getMembros().first;
      final promoviveis = <Membro>[];

      for (final membro in todosMembros) {
        if (membro.situacaoSEAE != idSituacaoColaborador) continue;

        if (!_temContribuicaoIninterrupta(membro, mesesContribuicaoIninterrupta + 1)) continue;

        promoviveis.add(membro);
      }

      if (mounted) {
        setState(() {
          _membrosPromoviveis = promoviveis;
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
      final dataAlvo = DateTime(hoje.year, hoje.month - (i + 1), 1);
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
      case 'situacao_nome':
        return _situacoesMap[membro.situacaoSEAE.toString()] ?? 'N/A';
      default:
        return '';
    }
  }

  Future<void> _gerarPdf() async {
    setState(() => _isGeneratingPdf = true);
    final pdf = pw.Document();
    final now = DateFormat("dd/MM/yyyy 'às' HH:mm").format(DateTime.now());

    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final boldFontData = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final boldTtf = pw.Font.ttf(boldFontData);

    final logoImage = await rootBundle.load('assets/images/logo_SEAE_azul.png');
    final image = pw.MemoryImage(logoImage.buffer.asUint8List());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: boldTtf,
        ),
        header: (context) => _buildHeader(now, image, boldTtf),
        build: (context) => [_buildContentTable(context)],
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
    setState(() => _isGeneratingPdf = false);
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading || _isGeneratingPdf,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sócios Colaboradores Promovíveis'),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _membrosPromoviveis.isNotEmpty && !_isGeneratingPdf
                  ? _gerarPdf
                  : null,
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) return Center(child: Text(_error!));
    if (_membrosPromoviveis.isEmpty && !_isLoading) return const Center(child: Text('Nenhum sócio promovível encontrado.'));

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
                  rows: _membrosPromoviveis.map((membro) {
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

  pw.Widget _buildHeader(String now, pw.MemoryImage logo, pw.Font font) {
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
                    pw.Text('Relação de Sócios Colaboradores Promovíveis a Efetivos', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, font: font)),
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
    final tableData = _membrosPromoviveis.map((membro) {
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
      child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
    );
  }
}