import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:projetos/widgets/loading_overlay.dart';
//NÃO TIRAR, universal_html não funciona aqui
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
    '01': 'janeiro', '02': 'fevereiro', '03': 'marco', '04': 'abril',
    '05': 'maio', '06': 'junho', '07': 'julho', '08': 'agosto',
    '09': 'setembro', '10': 'outubro', '11': 'novembro', '12': 'dezembro',
  };
  final List<String> mesesKeys = ['janeiro', 'fevereiro', 'marco', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
  final List<String> mesesAbreviados = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

  final Map<String, String> _availableFields = {
    'nome': 'Nome',
    'cpf': 'CPF',
    'data_proposta': 'Data de Proposta',
    'ultima_atualizacao': 'Última Atualização',
    'situacao_nome': 'Situação',
    'contribuicoes': 'Contribuições',
  };
  final Set<String> _activeColumns = {'nome', 'cpf', 'situacao_nome'};
  Map<String, String> _situacoesMap = {};
  String? _selectedYear;
  List<String> _availableYears = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _loadYears();
      await _loadSituacoes();
      await _apurarPromoviveis();
    } catch (e) {
      if(mounted) setState(() => _error = 'Erro ao carregar dados: $e');
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadYears() async {
    final years = await _cadastroService.getAnosContribuicao();
    if (mounted) {
      setState(() {
        _availableYears = years..sort((a,b)=>b.compareTo(a));
        _selectedYear = _availableYears.isNotEmpty ? _availableYears.first : DateTime.now().year.toString();
      });
    }
  }

  Future<void> _loadSituacoes() async {
    _situacoesMap = await _cadastroService.getSituacoes();
  }

  Future<void> _apurarPromoviveis() async {
    final todosMembros = await _cadastroService.getMembros().first;
    final promoviveis = <Membro>[];

    for (final membro in todosMembros) {
      if (membro.situacaoSEAE != idSituacaoColaborador) continue;
      // Regra: "mais de 12 meses" significa que precisamos checar 13 meses.
      if (_temContribuicaoIninterrupta(membro, mesesContribuicaoIninterrupta + 1)) {
        promoviveis.add(membro);
      }
    }
    if (mounted) {
      setState(() {
        _membrosPromoviveis = promoviveis..sort((a,b)=> a.nome.compareTo(b.nome));
      });
    }
  }

  bool _temContribuicaoIninterrupta(Membro membro, int totalMeses) {
    final hoje = DateTime.now();
    for (int i = 0; i < totalMeses; i++) {
      // Itera pelos meses anteriores, a partir do último mês fechado.
      final dataAlvo = DateTime(hoje.year, hoje.month - i, 1);
      final ano = dataAlvo.year.toString();
      final mesNome = _meses[dataAlvo.month.toString().padLeft(2, '0')];

      final contribuicaoAno = membro.contribuicao[ano] as Map<String, dynamic>?;
      if (contribuicaoAno == null) return false;

      final mesesData = contribuicaoAno['meses'] as Map<String, dynamic>?;
      if (mesesData == null || mesesData[mesNome] != true) {
        return false;
      }
    }
    return true;
  }

  String _getCellValue(Membro membro, String field) {
    if (field == 'contribuicoes') return '';
    switch (field) {
      case 'nome': return membro.nome;
      case 'cpf': return membro.dadosPessoais.cpf;
      case 'data_proposta': return membro.dataProposta;
      case 'ultima_atualizacao': return membro.dataAtualizacao;
      case 'situacao_nome': return _situacoesMap[membro.situacaoSEAE.toString()] ?? 'N/A';
      default: return '';
    }
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
              onPressed: _membrosPromoviveis.isNotEmpty && !_isGeneratingPdf ? _gerarPdf : null,
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
        _buildControls(),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: DataTable(
                  columns: _createColumns(),
                  rows: _createRows(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_activeColumns.contains('contribuicoes'))
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Ano',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _selectedYear,
                    items: _availableYears.map((String year) => DropdownMenuItem<String>(value: year, child: Text(year))).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) setState(() => _selectedYear = newValue);
                    },
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(child: _buildColumnSelection()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColumnSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Selecionar Colunas', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0, runSpacing: 4.0,
          children: _availableFields.entries.map((entry) {
            final field = entry.key;
            final label = entry.value;
            final isSelected = _activeColumns.contains(field);
            final isDefault = field == 'nome';

            return FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: isDefault ? null : (bool selected) {
                setState(() {
                  if (selected) _activeColumns.add(field);
                  else _activeColumns.remove(field);
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
    );
  }

  List<DataColumn> _createColumns() {
    List<DataColumn> columns = _activeColumns
        .where((field) => field != 'contribuicoes')
        .map((field) => DataColumn(label: Text(_availableFields[field] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))))
        .toList();

    if (_activeColumns.contains('contribuicoes')) {
      columns.addAll(mesesAbreviados.map((mes) => DataColumn(label: Text(mes, style: const TextStyle(fontWeight: FontWeight.bold)))));
    }
    return columns;
  }

  List<DataRow> _createRows() {
    return _membrosPromoviveis.map((membro) {
      List<DataCell> cells = _activeColumns
          .where((field) => field != 'contribuicoes')
          .map((field) => DataCell(Text(_getCellValue(membro, field))))
          .toList();

      if (_activeColumns.contains('contribuicoes') && _selectedYear != null) {
        final contribuicaoAno = membro.contribuicao[_selectedYear] as Map<String, dynamic>? ?? {};
        final mesesData = contribuicaoAno['meses'] as Map<String, dynamic>? ?? {};

        cells.addAll(mesesKeys.map((mesKey) {
          return DataCell(Center(
            child: Checkbox(value: mesesData[mesKey] ?? false, onChanged: null),
          ));
        }));
      }
      return DataRow(cells: cells);
    }).toList();
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
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: ttf, bold: boldTtf),
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
    if(mounted) setState(() => _isGeneratingPdf = false);
  }

  pw.Widget _buildPdfCheckbox(bool isChecked) {
    const checkMarkSvg = '''
    <svg viewBox="0 0 12 12" xmlns="http://www.w3.org/2000/svg">
      <path d="M2 5 L4 7 L8 3" stroke-width="1.5" stroke="black" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>''';

    return pw.Container(
      width: 12,
      height: 12,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.75),
      ),
      child: isChecked ? pw.SvgImage(svg: checkMarkSvg) : pw.Container(),
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
    final List<String> headerStrings = _activeColumns
        .where((field) => field != 'contribuicoes')
        .map((field) => _availableFields[field] ?? 'N/A').toList();

    if (_activeColumns.contains('contribuicoes')) {
      headerStrings.addAll(mesesAbreviados);
    }

    final List<pw.TableRow> tableRows = _membrosPromoviveis.map((membro) {
      final List<pw.Widget> cells = _activeColumns
          .where((field) => field != 'contribuicoes')
          .map((field) => pw.Container(
        alignment: pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.all(3),
        child: pw.Text(_getCellValue(membro, field), style: const pw.TextStyle(fontSize: 8)),
      ))
          .toList();

      if (_activeColumns.contains('contribuicoes') && _selectedYear != null) {
        final contribuicaoAno = membro.contribuicao[_selectedYear] as Map<String, dynamic>? ?? {};
        final mesesData = contribuicaoAno['meses'] as Map<String, dynamic>? ?? {};

        for (final mesKey in mesesKeys) {
          final isPaid = mesesData[mesKey] ?? false;
          cells.add(pw.Center(child: _buildPdfCheckbox(isPaid)));
        }
      }
      return pw.TableRow(children: cells);
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(width: 0.75, color: PdfColors.grey700),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: headerStrings.map((h) => pw.Container(
            padding: const pw.EdgeInsets.all(4),
            alignment: pw.Alignment.center,
            child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
          )).toList(),
        ),
        ...tableRows,
      ],
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