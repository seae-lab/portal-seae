import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/models/membro.dart';
import 'package:projetos/services/secretaria_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:projetos/widgets/loading_overlay.dart';

// Função de nível superior para ser executada em um isolate separado
Future<Uint8List> generatePdfInBackground(Map<String, dynamic> params) async {
  final members = params['members'] as List<Membro>;
  final selectedYear = params['selectedYear'] as String;
  final activeMonths = params['activeMonths'] as Set<String>;
  final meses = params['meses'] as List<String>;
  final mesesKeys = params['mesesKeys'] as List<String>;
  final logoBytes = params['logoBytes'] as Uint8List;
  final fontBytes = params['fontBytes'] as ByteData;
  final boldFontBytes = params['boldFontBytes'] as ByteData;
  final now = params['now'] as String;

  final pdf = pw.Document();
  final ttf = pw.Font.ttf(fontBytes);
  final boldTtf = pw.Font.ttf(boldFontBytes);
  final image = pw.MemoryImage(logoBytes);

  pw.Widget buildPdfCheckbox(bool isChecked) {
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

  final List<String> headerStrings = ['Nome', 'Dados\nAtualizados', ...activeMonths.map((monthKey) => meses[mesesKeys.indexOf(monthKey)])];
  final Map<int, pw.TableColumnWidth> columnWidths = {
    0: const pw.FlexColumnWidth(3.5),
    1: const pw.FlexColumnWidth(1),
  };
  for (int i = 0; i < activeMonths.length; i++) {
    columnWidths[i + 2] = const pw.FlexColumnWidth(0.6);
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: pw.ThemeData.withFont(base: ttf, bold: boldTtf),
      header: (context) => pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(bottom: 20.0),
        child: pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(image, width: 50, height: 50),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Controle de Contribuições Mensais - Ano: $selectedYear', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, font: boldTtf)),
                    pw.SizedBox(height: 5),
                    pw.Text('Gerado em: $now', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.SizedBox(width: 50),
              ],
            ),
            pw.Divider(color: PdfColors.grey),
          ],
        ),
      ),
      build: (context) => [
        pw.Table(
          border: pw.TableBorder.all(width: 0.75, color: PdfColors.grey700),
          columnWidths: columnWidths,
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: headerStrings.map((h) => pw.Container(
                padding: const pw.EdgeInsets.all(4),
                alignment: pw.Alignment.center,
                child: pw.Text(h.replaceAll('\n', ' '), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
              )).toList(),
            ),
            ...members.map((membro) {
              final contribuicaoAno = membro.contribuicao[selectedYear] as Map<String, dynamic>? ?? {};
              final mesesData = contribuicaoAno['meses'] as Map<String, dynamic>? ?? {};

              final List<pw.Widget> cells = [
                pw.Container(
                    alignment: pw.Alignment.centerLeft,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    child: pw.Text(membro.nome, style: const pw.TextStyle(fontSize: 8))
                ),
                pw.Center(child: buildPdfCheckbox(membro.atualizacao)),
              ];
              cells.addAll(activeMonths.map((monthKey) {
                final isPaid = mesesData[monthKey] ?? false;
                return pw.Center(child: buildPdfCheckbox(isPaid));
              }));
              return pw.TableRow(children: cells);
            }),
          ],
        ),
      ],
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 10.0),
        child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
      ),
    ),
  );

  return pdf.save();
}


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
  bool _isGeneratingPdf = false;

  String? _selectedYear;
  List<String> _selectedStatusIds = [];
  List<String> _availableYears = [];
  Map<String, String> _situacoesMap = {};

  final List<String> mesesKeys = ['janeiro', 'fevereiro', 'marco', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
  final List<String> meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
  late final Set<String> _activeMonths = Set<String>.from(mesesKeys);

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
      await _loadAllMembers();
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro ao carregar dados: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSituacoes() async {
    try {
      _situacoesMap = await _cadastroService.getSituacoes();
      final idSocioEfetivo = _situacoesMap.keys.firstWhere((k) => _situacoesMap[k] == 'Sócio Efetivo', orElse: () => '4');
      if (mounted) setState(() => _selectedStatusIds = [idSocioEfetivo]);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro ao carregar as situações: $e');
    }
  }

  Future<void> _loadAllMembers() async {
    try {
      final members = await _cadastroService.getMembros().first;
      if (mounted) {
        setState(() {
          _allMembers = members;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro ao carregar membros: $e');
    }
  }

  Future<void> _loadYears() async {
    try {
      final years = await _cadastroService.getAnosContribuicao();
      if (mounted) {
        setState(() {
          _availableYears = years..sort((a, b) => b.compareTo(a));
          _selectedYear = _availableYears.isNotEmpty ? _availableYears.first : DateTime.now().year.toString();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro ao carregar anos: $e');
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredMembers = _allMembers.where((membro) {
        final matchesStatus = _selectedStatusIds.isEmpty || _selectedStatusIds.contains(membro.situacaoSEAE.toString());
        return matchesStatus;
      }).toList();
      _filteredMembers.sort((a, b) => a.nome.compareTo(b.nome));
    });
  }

  Future<void> _gerarPdf() async {
    setState(() => _isGeneratingPdf = true);

    try {
      final logoBytes = (await rootBundle.load('assets/images/logo_SEAE_azul.png')).buffer.asUint8List();
      final fontBytes = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
      final boldFontBytes = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
      final now = DateFormat("dd/MM/yyyy 'às' HH:mm").format(DateTime.now());

      final params = {
        'members': _filteredMembers,
        'selectedYear': _selectedYear!,
        'activeMonths': _activeMonths,
        'meses': meses,
        'mesesKeys': mesesKeys,
        'logoBytes': logoBytes,
        'fontBytes': fontBytes,
        'boldFontBytes': boldFontBytes,
        'now': now,
      };

      final bytes = await compute(generatePdfInBackground, params);

      if (kIsWeb) {
        final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'application/pdf'));
        final url = web.URL.createObjectURL(blob);
        web.window.open(url, '_blank');
        web.URL.revokeObjectURL(url);
      } else {
        await Printing.layoutPdf(onLayout: (format) async => bytes);
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
    } finally {
      if(mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading || _isGeneratingPdf,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Controle de Contribuições'),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: (_filteredMembers.isNotEmpty && _selectedYear != null && !_isGeneratingPdf) ? _gerarPdf : null,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildFilterAndColumnSelection(),
              const SizedBox(height: 16),
              if (_error != null)
                Expanded(child: Center(child: Text(_error!)))
              else
                _buildDataTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterAndColumnSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16.0,
          runSpacing: 8.0,
          alignment: WrapAlignment.center,
          children: [
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Ano',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                value: _selectedYear,
                items: _availableYears.map((String year) {
                  return DropdownMenuItem<String>(
                    value: year,
                    child: Text(year),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedYear = newValue;
                      _applyFilters();
                    });
                  }
                },
              ),
            ),
            SizedBox(
              width: 200,
              child: InkWell(
                onTap: () => _showMultiSelectDialog(
                  title: 'Filtrar por Situação',
                  options: _situacoesMap.entries.map((e) => e.value).toList(),
                  selectedOptions: _selectedStatusIds.map((id) => _situacoesMap[id] ?? id).toList(),
                  onConfirm: (values) {
                    setState(() {
                      final Map<String, String> reversedSituacoes = _situacoesMap.map((key, value) => MapEntry(value, key));
                      _selectedStatusIds = values.map((name) => reversedSituacoes[name] ?? '').where((id) => id.isNotEmpty).toList();
                      _applyFilters();
                    });
                  },
                ),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Situação',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(_selectedStatusIds.isEmpty
                      ? 'Todas as Situações'
                      : '${_selectedStatusIds.length} Selecionada(s)'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Selecionar Meses', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: meses.asMap().entries.map((entry) {
            final monthIndex = entry.key;
            final monthLabel = entry.value;
            final monthKey = mesesKeys[monthIndex];
            final isSelected = _activeMonths.contains(monthKey);

            return FilterChip(
              label: Text(monthLabel),
              selected: isSelected,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    _activeMonths.add(monthKey);
                  } else {
                    _activeMonths.remove(monthKey);
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
    );
  }

  Widget _buildDataTable() {
    if (_filteredMembers.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text('Nenhum membro encontrado com os filtros selecionados.'),
        ),
      );
    }
    return Expanded(
      child: SingleChildScrollView(
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
                ..._activeMonths.map((monthKey) {
                  final monthLabel = meses[mesesKeys.indexOf(monthKey)];
                  return DataColumn(label: Text(monthLabel, style: const TextStyle(fontWeight: FontWeight.bold)));
                }),
              ],
              rows: _filteredMembers.map((membro) {
                final year = _selectedYear ?? DateTime.now().year.toString();
                final contribuicaoAno = membro.contribuicao[year] as Map<String, dynamic>? ?? {};
                final mesesData = contribuicaoAno['meses'] as Map<String, dynamic>? ?? {};

                return DataRow(cells: [
                  DataCell(Text(membro.nome)),
                  DataCell(Center(child: Checkbox(value: membro.atualizacao, onChanged: null))),
                  ..._activeMonths.map((monthKey) => DataCell(Center(child: Checkbox(value: mesesData[monthKey] ?? false, onChanged: null)))),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _showMultiSelectDialog({
    required String title,
    required List<String> options,
    required List<String> selectedOptions,
    required Function(List<String>) onConfirm,
  }) {
    final List<String> tempSelected = List.from(selectedOptions);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: options.map((option) {
                    final isSelected = tempSelected.contains(option);
                    return CheckboxListTile(
                      title: Text(option),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            tempSelected.add(option);
                          } else {
                            tempSelected.remove(option);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    onConfirm(tempSelected);
                    Navigator.of(context).pop();
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
}