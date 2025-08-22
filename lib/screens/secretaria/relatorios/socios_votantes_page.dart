// lib/screens/secretaria/relatorios/socios_votantes_page.dart

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

class SociosVotantesPage extends StatefulWidget {
  const SociosVotantesPage({super.key});

  @override
  State<SociosVotantesPage> createState() => _SociosVotantesPageState();
}

class _SociosVotantesPageState extends State<SociosVotantesPage> {
  final CadastroService _cadastroService = Modular.get<CadastroService>();
  List<Membro> _membrosVotantes = [];
  bool _isLoading = true;
  String? _error;
  late DateTime _dataBase;
  bool _isGeneratingPdf = false;

  String? _selectedYear;
  List<String> _availableYears = [];
  Map<String, String> _situacoesMap = {};
  final Set<String> _activeColumns = {'nome', 'cpf'};
  final List<String> mesesKeys = ['janeiro', 'fevereiro', 'marco', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
  final List<String> mesesAbreviados = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

  static const int idSituacaoEfetivo = 4;

  final Map<String, String> _meses = {
    '01': 'janeiro', '02': 'fevereiro', '03': 'marco', '04': 'abril',
    '05': 'maio', '06': 'junho', '07': 'julho', '08': 'agosto',
    '09': 'setembro', '10': 'outubro', '11': 'novembro', '12': 'dezembro',
  };

  final Map<String, String> _availableFields = {
    'nome': 'Nome',
    'cpf': 'CPF',
    'data_proposta': 'Data de Proposta',
    'ultima_atualizacao': 'Última Atualização',
    'situacao_nome': 'Situação',
    'contribuicoes': 'Contribuições',
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // A data base padrão para votação é sempre 31 de Agosto do ano vigente.
    _dataBase = DateTime(now.year, 8, 31);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _loadYears();
      await _loadSituacoes();
      await _apurarVotantes(_dataBase);
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

  Future<void> _apurarVotantes(DateTime dataBase) async {
    final todosMembros = await _cadastroService.getMembros().first;
    final votantes = <Membro>[];

    for (final membro in todosMembros) {
      // Regra: ser sócio efetivo (situação 4)
      if (membro.situacaoSEAE != idSituacaoEfetivo) continue;

      // Regra: ter contribuído regularmente nos 12 meses que antecedem a data-base
      if (!_temContribuicaoRegularVotante(membro, dataBase)) continue;

      votantes.add(membro);
    }

    if (mounted) {
      setState(() {
        _membrosVotantes = votantes..sort((a, b) => a.nome.compareTo(b.nome));
      });
    }
  }

  // LÓGICA ATUALIZADA: Verificação estrita dos 12 meses anteriores à data base.
  bool _temContribuicaoRegularVotante(Membro membro, DateTime dataBase) {
    for (int i = 0; i < 12; i++) {
      // Calcula o mês a ser verificado, voltando a partir da data base.
      final dataAlvo = DateTime(dataBase.year, dataBase.month - i, 1);
      final ano = dataAlvo.year.toString();
      final mesNome = _meses[dataAlvo.month.toString().padLeft(2, '0')];

      final contribuicaoAno = membro.contribuicao[ano] as Map<String, dynamic>?;
      if (contribuicaoAno == null) return false;

      final mesesData = contribuicaoAno['meses'] as Map<String, dynamic>?;
      if (mesesData == null || mesesData[mesNome] != true) {
        return false; // Exige que o mês específico esteja marcado como pago.
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
          title: const Text('Sócios Votantes'),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _membrosVotantes.isNotEmpty && !_isGeneratingPdf ? _gerarPdf : null,
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) return Center(child: Text(_error!));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Data Base da Eleição:'),
              TextButton(
                onPressed: () => _selectDataBase(context),
                child: Text(DateFormat('dd/MM/yyyy').format(_dataBase)),
              ),
            ],
          ),
        ),
        _buildControls(),
        if (_membrosVotantes.isEmpty && !_isLoading)
          const Expanded(
            child: Center(
              child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Nenhum sócio efetivo apto a votar encontrado para a data base selecionada.')
              ),
            ),
          )
        else
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
      padding: const EdgeInsets.symmetric(horizontal:16.0),
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
    return _membrosVotantes.map((membro) {
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

  Future<void> _selectDataBase(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataBase,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year, 12, 31),
      helpText: 'Selecione a data da eleição',
    );
    if (picked != null) {
      // Usa a data exata selecionada pelo usuário
      if (picked != _dataBase) {
        setState(() {
          _dataBase = picked;
          _isLoading = true;
        });
        await _apurarVotantes(_dataBase);
        setState(() {
          _isLoading = false;
        });
      }
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
                    pw.Text('Relação de Sócios Efetivos Votantes', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, font: font)),
                    pw.SizedBox(height: 5),
                    pw.Text('Apuração com data base em: ${DateFormat('dd/MM/yyyy').format(_dataBase)}', style: const pw.TextStyle(fontSize: 10)),
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
    final List<String> tableHeaders = _activeColumns
        .where((field) => field != 'contribuicoes')
        .map((field) => _availableFields[field] ?? 'N/A').toList();

    if (_activeColumns.contains('contribuicoes')) {
      tableHeaders.addAll(mesesAbreviados);
    }

    final List<List<String>> tableData = _membrosVotantes.map((membro) {
      final List<String> rowData = _activeColumns
          .where((field) => field != 'contribuicoes')
          .map((field) => _getCellValue(membro, field)).toList();

      if (_activeColumns.contains('contribuicoes') && _selectedYear != null) {
        final contribuicaoAno = membro.contribuicao[_selectedYear] as Map<String, dynamic>? ?? {};
        final mesesData = contribuicaoAno['meses'] as Map<String, dynamic>? ?? {};
        for (final mesKey in mesesKeys) {
          rowData.add((mesesData[mesKey] ?? false) ? 'X' : '');
        }
      }
      return rowData;
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: tableHeaders,
      data: tableData,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 7),
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