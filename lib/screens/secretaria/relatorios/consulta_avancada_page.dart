import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:projetos/services/cadastro_service.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:projetos/widgets/loading_overlay.dart';
import '../../../models/membro.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
//NÃO TIRAR, universal_html não funciona aqui
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:flutter/services.dart';

class ConsultaAvancadaPage extends StatefulWidget {
  const ConsultaAvancadaPage({super.key});

  @override
  State<ConsultaAvancadaPage> createState() => _ConsultaAvancadaPageState();
}

class _ConsultaAvancadaPageState extends State<ConsultaAvancadaPage> {
  final CadastroService _cadastroService = Modular.get<CadastroService>();
  List<Membro> _allMembers = [];
  List<Membro> _resultados = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isGeneratingPdf = false;
  bool _hasSearched = false;

  final List<Filter> _filters = [Filter(field: 'nome', value: '')];
  final Set<String> _activeColumns = {'nome', 'dados_pessoais.cpf'};

  Map<String, String> _situacoesMap = {};

  final Map<String, String> _availableFields = {
    'nome': 'Nome',
    'dados_pessoais.cpf': 'CPF',
    'dados_pessoais.cidade': 'Cidade',
    'data_proposta': 'Data de Proposta',
    'ultima_atualizacao': 'Última Atualização',
    'contribuicao_anual': 'Contribuição Anual',
    'contribuicao_mensal': 'Contribuição Mensal',
    'atividades': 'Atividade (Departamento)',
    'dados_pessoais.data_nascimento': 'Data de Nascimento',
    'situacao_seae': 'Situação',
  };

  final Map<String, String> _operators = {
    'igual a': '==',
    'diferente de': '!=',
    'contém': 'contém',
    'não contém': 'não contém',
    'começa com': 'começa com',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final situacoes = await _cadastroService.getSituacoes();
      final members = await _cadastroService.getMembros().first;
      if (mounted) {
        setState(() {
          _situacoesMap = situacoes;
          _allMembers = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $e')));
      }
    }
  }

  String _getCellValue(Membro membro, String field) {
    switch (field) {
      case 'nome': return membro.nome;
      case 'dados_pessoais.cpf': return membro.dadosPessoais.cpf;
      case 'dados_pessoais.cidade': return membro.dadosPessoais.cidade;
      case 'data_proposta': return membro.dataProposta;
      case 'ultima_atualizacao': return membro.dataAtualizacao;
      case 'atividades': return membro.atividades.join(', ');
      case 'dados_pessoais.data_nascimento': return membro.dadosPessoais.dataNascimento;
      case 'situacao_seae': return _situacoesMap[membro.situacaoSEAE.toString()] ?? 'N/D';
      case 'contribuicao_anual':
      case 'contribuicao_mensal':
        final paidYears = <String>[];
        membro.contribuicao.forEach((year, data) {
          if (data is Map) {
            final isYearlyPaid = data['quitado'] as bool? ?? false;
            final monthsData = data['meses'] as Map<String, dynamic>?;
            final hasAnyMonthlyPayment = monthsData?.values.any((isPaid) => isPaid == true) ?? false;
            if (isYearlyPaid || hasAnyMonthlyPayment) {
              paidYears.add(year);
            }
          }
        });
        return paidYears.join(', ');
      default: return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isGeneratingPdf,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Consulta Avançada'),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _resultados.isNotEmpty && !_isGeneratingPdf ? _gerarPdf : null,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterSection(),
              const SizedBox(height: 16),
              _buildColumnSelection(),
              const SizedBox(height: 16),
              _buildButtons(),
              const SizedBox(height: 16),
              _buildResultsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ..._filters.asMap().entries.map((entry) {
              final idx = entry.key;
              final filter = entry.value;
              return LayoutBuilder(
                builder: (context, constraints) {
                  bool useColumn = constraints.maxWidth < 650;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Flex(
                      direction: useColumn ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: useColumn ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
                      children: [
                        _buildFilterDropdown(
                          label: 'Campo',
                          value: filter.field,
                          items: _availableFields.entries.map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value))).toList(),
                          onChanged: (newValue) => setState(() => filter.field = newValue!),
                          isFlexible: !useColumn,
                        ),
                        if (!useColumn) const SizedBox(width: 8),
                        if (useColumn) const SizedBox(height: 8),
                        _buildFilterDropdown(
                          label: 'Operador',
                          value: filter.operator,
                          items: _operators.entries.map((e) => DropdownMenuItem<String>(value: e.value, child: Text(e.key))).toList(),
                          onChanged: (newValue) => setState(() => filter.operator = newValue!),
                          isFlexible: !useColumn,
                        ),
                        if (!useColumn) const SizedBox(width: 8),
                        if (useColumn) const SizedBox(height: 8),
                        _buildFilterTextField(
                          onChanged: (newValue) => filter.value = newValue,
                          hintText: filter.field == 'contribuicao_mensal' ? 'Ex: 2025/janeiro' : 'Valor',
                          isFlexible: !useColumn,
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                          onPressed: _filters.length > 1 ? () => _removeFilter(idx) : null,
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
            if (_filters.length < 5)
              TextButton.icon(onPressed: _addFilter, icon: const Icon(Icons.add), label: const Text('Adicionar Filtro')),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({required String label, required String value, required List<DropdownMenuItem<String>> items, required ValueChanged<String?> onChanged, bool isFlexible = false}) {
    final dropdown = DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: items,
      onChanged: onChanged,
    );
    return isFlexible ? Expanded(child: dropdown) : dropdown;
  }

  Widget _buildFilterTextField({required ValueChanged<String> onChanged, String? hintText, bool isFlexible = false}) {
    final textField = TextFormField(
      decoration: InputDecoration(labelText: 'Valor', hintText: hintText, border: const OutlineInputBorder()),
      onChanged: onChanged,
    );
    return isFlexible ? Expanded(flex: 2, child: textField) : textField;
  }

  Widget _buildColumnSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Selecionar Colunas para Exibição', style: Theme.of(context).textTheme.titleSmall),
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
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: _isSearching ? null : _performSearch,
          child: _isSearching
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Buscar'),
        ),
      ],
    );
  }

  Widget _buildResultsSection() {
    if (!_hasSearched) {
      return const Center(child: Text('Defina os filtros e clique em "Buscar" para ver os resultados.'));
    }
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_resultados.isEmpty) {
      return const Center(child: Text('Nenhum resultado encontrado.'));
    }

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: _activeColumns.map((field) {
            return DataColumn(label: Text(_availableFields[field] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)));
          }).toList(),
          rows: _resultados.map((membro) => DataRow(
            cells: _activeColumns.map((field) {
              return DataCell(Text(_getCellValue(membro, field)));
            }).toList(),
          )).toList(),
        ),
      ),
    );
  }

  void _addFilter() {
    setState(() => _filters.add(Filter(field: _availableFields.keys.first, value: '')));
  }

  void _removeFilter(int index) {
    setState(() => _filters.removeAt(index));
  }

  void _performSearch() {
    setState(() => _isSearching = true);
    try {
      _resultados = _allMembers.where((membro) {
        return _filters.every((filter) {
          if (filter.value.isEmpty) return true;
          final fieldValue = _getFieldValue(membro, filter.field);
          return _checkCondition(fieldValue, filter.operator, filter.value, filter.field);
        });
      }).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao buscar: $e')));
    } finally {
      setState(() {
        _isSearching = false;
        _hasSearched = true;
      });
    }
  }

  dynamic _getFieldValue(Membro membro, String field) {
    switch (field) {
      case 'nome': return membro.nome;
      case 'dados_pessoais.cpf': return membro.dadosPessoais.cpf;
      case 'dados_pessoais.cidade': return membro.dadosPessoais.cidade;
      case 'data_proposta': return membro.dataProposta;
      case 'ultima_atualizacao': return membro.dataAtualizacao;
      case 'contribuicao_anual': return membro.contribuicao;
      case 'contribuicao_mensal': return membro.contribuicao;
      case 'atividades': return membro.atividades;
      case 'dados_pessoais.data_nascimento': return membro.dadosPessoais.dataNascimento;
      case 'situacao_seae': return _situacoesMap[membro.situacaoSEAE.toString()] ?? '';
      default: return null;
    }
  }

  bool _checkCondition(dynamic fieldValue, String operator, String filterValue, String fieldKey) {
    if (fieldValue == null) return false;

    // Lógica para contribuição anual
    if (fieldKey == 'contribuicao_anual') {
      final yearToFind = filterValue;
      final yearData = (fieldValue as Map<String, dynamic>)[yearToFind] as Map<String, dynamic>?;

      bool hasContributedInYear = false;
      if (yearData != null) {
        final isYearlyPaid = yearData['quitado'] as bool? ?? false;
        final monthsData = yearData['meses'] as Map<String, dynamic>?;
        final hasAnyMonthlyPayment = monthsData?.values.any((isPaid) => isPaid == true) ?? false;
        if (isYearlyPaid || hasAnyMonthlyPayment) {
          hasContributedInYear = true;
        }
      }

      switch (operator) {
        case '==': case 'contém': return hasContributedInYear;
        case '!=': case 'não contém': return !hasContributedInYear;
        default: return false;
      }
    }

    // Lógica para contribuição mensal
    if (fieldKey == 'contribuicao_mensal') {
      if (!filterValue.contains('/')) return false;
      final parts = filterValue.split('/');
      if(parts.length < 2) return false;
      final year = parts[0];
      final month = parts[1].toLowerCase();

      final yearData = (fieldValue as Map<String, dynamic>)[year] as Map<String, dynamic>?;
      if (yearData == null) return operator == '!=' || operator == 'não contém';

      final isYearlyPaid = yearData['quitado'] as bool? ?? false;
      final monthsData = yearData['meses'] as Map<String, dynamic>?;
      final isMonthlyPaid = monthsData != null && (monthsData[month] == true);
      final monthIsPaid = isYearlyPaid || isMonthlyPaid;

      switch (operator) {
        case '==': case 'contém': return monthIsPaid;
        case '!=': case 'não contém': return !monthIsPaid;
        default: return false;
      }
    }

    // Lógica padrão para strings e listas
    final lowerFilterValue = filterValue.toLowerCase();
    if (fieldValue is List) {
      switch (operator) {
        case '==': case 'contém': return fieldValue.any((item) => item.toString().toLowerCase().contains(lowerFilterValue));
        case '!=': return !fieldValue.any((item) => item.toString().toLowerCase() == lowerFilterValue);
        case 'não contém': return !fieldValue.any((item) => item.toString().toLowerCase().contains(lowerFilterValue));
        default: return false;
      }
    }

    final lowerFieldValue = fieldValue.toString().toLowerCase();
    switch (operator) {
      case '==': return lowerFieldValue == lowerFilterValue;
      case '!=': return lowerFieldValue != lowerFilterValue;
      case 'contém': return lowerFieldValue.contains(lowerFilterValue);
      case 'não contém': return !lowerFieldValue.contains(lowerFilterValue);
      case 'começa com': return lowerFieldValue.startsWith(lowerFilterValue);
      default: return false;
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
    setState(() => _isGeneratingPdf = false);
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
                    pw.Text('Relatório de Consulta Avançada', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, font: font)),
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
    final tableData = _resultados.map((membro) {
      return _activeColumns.map((field) {
        if(field == 'contribuicao_anual' || field == 'contribuicao_mensal') {
          return membro.contribuicao.keys.join(', ');
        }
        return _getCellValue(membro, field);
      }).toList();
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

class Filter {
  String field;
  String operator;
  String value;

  Filter({required this.field, this.operator = '==', required this.value});
}