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
  State<ControleContribuicoesPage> createState() => _ControleContribuicoesPageState();
}

class _ControleContribuicoesPageState extends State<ControleContribuicoesPage> {
  final CadastroService _cadastroService = Modular.get<CadastroService>();
  List<Membro> _allMembers = [];
  List<Membro> _filteredMembers = [];
  bool _isLoading = true;
  String? _error;

  String? _selectedYear;
  List<String> _selectedStatusIds = [];

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

    if (_selectedStatusIds.isNotEmpty) {
      filtered = filtered.where((m) => _selectedStatusIds.contains(m.situacaoSEAE.toString())).toList();
    }

    filtered.sort((a, b) => a.nome.compareTo(b.nome));

    setState(() {
      _filteredMembers = filtered;
    });
  }

  Future<Uint8List> _buildPdfBytes() async {
    final pdf = pw.Document();
    final year = _selectedYear ?? DateTime.now().year.toString();
    final List<String> meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final List<String> mesesKeys = ['janeiro', 'fevereiro', 'marco', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];

    const checkMark = '✓';
    const emptyBox = '☐';

    final headers = ['Nome', 'Dados At.', ...meses];

    final data = _filteredMembers.map((membro) {
      final contribuicaoAno = membro.contribuicao[year] as Map<String, dynamic>? ?? {};
      final mesesData = contribuicaoAno['meses'] as Map<String, dynamic>? ?? {};

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
            context: context,
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
      final blob = web.Blob(
        [bytes.toJS].toJS,
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
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            child: _buildMultiSelectStatusFilter(),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectStatusFilter() {
    return InkWell(
      onTap: () => _showMultiSelectStatusDialog(),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Situação',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: _selectedStatusIds.isEmpty
            ? const Text('Todas as Situações')
            : Wrap(
          spacing: 6.0,
          runSpacing: 6.0,
          children: _selectedStatusIds.map((id) {
            return Chip(
              label: Text(_situacoesMap[id] ?? 'N/D'),
              onDeleted: () {
                setState(() {
                  _selectedStatusIds.remove(id);
                  _applyFilters();
                });
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showMultiSelectStatusDialog() async {
    final List<String> tempSelected = List.from(_selectedStatusIds);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Selecione as Situações'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _situacoesMap.entries.map((entry) {
                    final isSelected = tempSelected.contains(entry.key);
                    return CheckboxListTile(
                      title: Text(entry.value),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            tempSelected.add(entry.key);
                          } else {
                            tempSelected.remove(entry.key);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedStatusIds = tempSelected;
                      _applyFilters();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDataTable() {
    if (_filteredMembers.isEmpty) {
      return const Center(child: Text('Nenhum membro encontrado com os filtros selecionados.'));
    }

    final List<String> meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final List<String> mesesKeys = ['janeiro', 'fevereiro', 'marco', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
    final year = _selectedYear ?? DateTime.now().year.toString();

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: DataTable(
            headingRowColor: WidgetStateColor.resolveWith((states) => Colors.grey.shade200),
            columns: [
              const DataColumn(label: Text('Nome', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Dados\nAtualizados', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
              ...meses.map((mes) => DataColumn(label: Text(mes, style: const TextStyle(fontWeight: FontWeight.bold)))),
            ],
            rows: _filteredMembers.map((membro) {
              final contribuicaoAno = membro.contribuicao[year] as Map<String, dynamic>? ?? {};
              final mesesData = contribuicaoAno['meses'] as Map<String, dynamic>? ?? {};

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