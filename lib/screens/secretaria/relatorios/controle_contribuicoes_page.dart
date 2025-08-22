import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/cadastro_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
//NÃO TIRAR, universal_html não funciona aqui
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:projetos/widgets/loading_overlay.dart';
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
  bool _isGeneratingPdf = false;

  // Estados dos filtros
  String? _selectedYear;
  List<String> _selectedStatusIds = [];

  // Listas para os filtros
  List<String> _availableYears = [];
  Map<String, String> _situacoesMap = {};

  // Colunas
  final List<String> mesesKeys = ['janeiro', 'fevereiro', 'marco', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
  final List<String> meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
  late final Set<String> _activeMonths = Set<String>.from(mesesKeys);

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
    try {
      await _loadYears();
      await _loadSituacoes();
      await _loadAllMembers();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar dados: $e';
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

  Future<void> _loadSituacoes() async {
    try {
      _situacoesMap = await _cadastroService.getSituacoes();
      final idSocioEfetivo = _situacoesMap.keys.firstWhere((k) => _situacoesMap[k] == 'Sócio Efetivo', orElse: () => '4');
      if(mounted) {
        setState(() {
          _selectedStatusIds = [idSocioEfetivo]; // Define o padrão
        });
      }
    } catch (e) {
      if(mounted) {
        setState(() {
          _error = 'Erro ao carregar as situações: $e';
        });
      }
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
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar membros: $e';
        });
      }
    }
  }

  Future<void> _loadYears() async {
    try {
      final years = await _cadastroService.getAnosContribuicao();
      if (mounted) {
        setState(() {
          _availableYears = years;
          _selectedYear = _availableYears.isNotEmpty ? _availableYears.first : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar anos: $e';
        });
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredMembers = _allMembers.where((membro) {
        final matchesStatus = _selectedStatusIds.isEmpty || _selectedStatusIds.contains(membro.situacaoSEAE.toString());
        final hasSelectedYearData = _selectedYear == null || (membro.contribuicao[_selectedYear] as Map<String, dynamic>?) != null;
        return matchesStatus && hasSelectedYearData;
      }).toList();

      _filteredMembers.sort((a, b) => a.nome.compareTo(b.nome));
    });
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
    return LoadingOverlay( // Adicionado o LoadingOverlay
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
                initialValue: _selectedYear,
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

  // Método para o diálogo multi-seleção
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
                    pw.Text('Controle de Contribuições Mensais', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, font: font)),
                    pw.SizedBox(height: 5),
                    pw.Text('Gerado em: $now', style: const pw.TextStyle(fontSize: 8)),
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
    final year = _selectedYear ?? DateTime.now().year.toString();
    final tableHeaders = ['Nome', 'Dados Atualizados', ..._activeMonths.map((monthKey) => meses[mesesKeys.indexOf(monthKey)])];
    final tableData = _filteredMembers.map((membro) {
      final contribuicaoAno = membro.contribuicao[year] as Map<String, dynamic>? ?? {};
      final mesesData = contribuicaoAno['meses'] as Map<String, dynamic>? ?? {};
      return [
        membro.nome,
        membro.atualizacao ? 'Sim' : 'Não',
        ..._activeMonths.map((monthKey) => (mesesData[monthKey] ?? false) ? 'Sim' : 'Não'),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: tableHeaders,
      data: tableData,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
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