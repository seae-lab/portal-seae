// lib/screens/home/pages/secretaria/controle_contribuicoes_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/cadastro_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../../../models/membro.dart';

class ControleContribuicoesPage extends StatefulWidget {
  const ControleContribuicoesPage({super.key});

  @override
  State<ControleContribuicoesPage> createState() =>
      _ControleContribuicoesPageState();
}

class _ControleContribuicoesPageState extends State<ControleContribuicoesPage> {
  final CadastroService _cadastroService = Modular.get<CadastroService>();
  List<Membro> _allMembers = [];
  List<Membro> _filteredMembers = [];
  bool _isLoading = true;
  String? _error;

  // Estados dos filtros
  String? _selectedYear;
  String? _selectedStatusId;

  // Listas para os filtros
  List<String> _availableYears = [];
  Map<String, String> _situacoesMap = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final all = await _cadastroService.getMembros().first;
      final anos = await _cadastroService.getAnosContribuicao();
      final situacoes = await _cadastroService.getSituacoes();

      if (mounted) {
        setState(() {
          _allMembers = all.where((m) => m.listaContribuintes).toList();
          _availableYears = anos..sort((a, b) => b.compareTo(a));
          _situacoesMap = situacoes;

          if (_availableYears.isNotEmpty) {
            _selectedYear = _availableYears.first;
          }
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Falha ao carregar dados: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    List<Membro> filtered = List.from(_allMembers);

    if (_selectedStatusId != null) {
      filtered = filtered
          .where((m) => m.situacaoSEAE.toString() == _selectedStatusId)
          .toList();
    }

    filtered.sort((a, b) => a.nome.compareTo(b.nome));

    setState(() {
      _filteredMembers = filtered;
    });
  }

  Future<Uint8List> _buildPdfBytes() async {
    final pdf = pw.Document();
    final year = _selectedYear ?? DateTime.now().year.toString();
    final List<String> meses = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    final List<String> mesesKeys = ['janeiro','fevereiro','marco','abril','maio','junho','julho','agosto','setembro','outubro','novembro','dezembro'];

    const checkMark = '✓';
    const emptyBox = '☐';

    final headers = ['Nome', 'Dados At.', ...meses];

    final data = _filteredMembers.map((membro) {
      final contribuicaoAno =
          membro.contribuicao[year] as Map<String, dynamic>? ?? {};
      final mesesData =
          contribuicaoAno['meses'] as Map<String, dynamic>? ?? {};

      final row = <String>[];
      row.add(membro.nome);
      row.add(membro.atualizacao ? checkMark : emptyBox);

      for (final mesKey in mesesKeys) {
        row.add(mesesData[mesKey] == true ? checkMark : emptyBox);
      }
      return row;
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            text: 'Controle de Contribuições Mensais - $year',
            textStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
          ),
          pw.TableHelper.fromTextArray(
            context: context, // O 'context' vem do builder do MultiPage
            headers: headers,
            data: data,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> _generateAndDownloadPdf() async {
    final bytes = await _buildPdfBytes();
    if (kIsWeb) {
      // FINAL CORRECTION: Convert the inner Uint8List, then the list.
      final blob = web.Blob(
        [bytes.toJS].toJS, // Correct conversion
        web.BlobPropertyBag(type: 'application/pdf'),
      );
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = 'controle_contribuicoes_$_selectedYear.pdf';
      web.document.body?.append(anchor);
      anchor.click();
      web.document.body?.removeChild(anchor);
      web.URL.revokeObjectURL(url);
    } else {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes);
    }
  }

  Future<void> _generateAndPrintPdf() async {
    final bytes = await _buildPdfBytes();
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Controle de Contribuições - ${_selectedYear ?? ''}'),
        actions: [
          if (!_isLoading && _filteredMembers.isNotEmpty)
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _generateAndDownloadPdf,
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('Gerar PDF'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: 'Imprimir Relatório',
                  onPressed: _generateAndPrintPdf,
                ),
                const SizedBox(width: 16),
              ],
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildDataTable()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedYear,
              hint: const Text('Selecione o Ano'),
              decoration: const InputDecoration(
                labelText: 'Ano',
                border: OutlineInputBorder(),
                contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _availableYears.map((year) {
                return DropdownMenuItem(value: year, child: Text(year));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedYear = value;
                  _applyFilters();
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedStatusId,
              hint: const Text('Todas as Situações'),
              decoration: const InputDecoration(
                labelText: 'Situação',
                border: OutlineInputBorder(),
                contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem<String>(
                    value: null, child: Text('Todas as Situações')),
                ..._situacoesMap.entries.map((entry) =>
                    DropdownMenuItem<String>(
                        value: entry.key, child: Text(entry.value))),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatusId = value;
                  _applyFilters();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    if (_filteredMembers.isEmpty) {
      return const Center(
          child: Text('Nenhum membro encontrado com os filtros selecionados.'));
    }

    final List<String> meses = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    final List<String> mesesKeys = ['janeiro','fevereiro','marco','abril','maio','junho','julho','agosto','setembro','outubro','novembro','dezembro'];
    final year = _selectedYear ?? DateTime.now().year.toString();

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: DataTable(
            headingRowColor:
            WidgetStateColor.resolveWith((states) => Colors.grey.shade200),
            columns: [
              const DataColumn(label: Text('Nome', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Dados\nAtualizados', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
              ...meses.map((mes) => DataColumn(label: Text(mes, style: const TextStyle(fontWeight: FontWeight.bold)))),
            ],
            rows: _filteredMembers.map((membro) {
              final contribuicaoAno =
                  membro.contribuicao[year] as Map<String, dynamic>? ?? {};
              final mesesData =
                  contribuicaoAno['meses'] as Map<String, dynamic>? ?? {};

              return DataRow(cells: [
                DataCell(Text(membro.nome)),
                DataCell(Center(child: Checkbox(value: membro.atualizacao, onChanged: null))),
                ...mesesKeys.map((mesKey) => DataCell(Center(child: Checkbox(value: mesesData[mesKey] ?? false, onChanged: null)))),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}