// lib/screens/secretaria/relatorios/consulta_avancada_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:projetos/services/cadastro_service.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../../../models/membro.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
  List<Membro> _resultados = [];
  bool _isLoading = false;

  final List<Filter> _filters = [Filter(field: 'nome', value: '')];
  final Set<String> _activeColumns = {'nome', 'dados_pessoais.cpf'};

  Map<String, String> _situacoesMap = {};

  final Map<String, String> _availableFields = {
    'nome': 'Nome',
    'dados_pessoais.cpf': 'CPF',
    'dados_pessoais.cidade': 'Cidade',
    'data_proposta': 'Data de Proposta',
    'ultima_atualizacao': 'Última Atualização',
    'contribuicao': 'Contribuição',
    'atividades': 'Atividade (Departamento)', // Corrigido
    'dados_pessoais.data_nascimento': 'Data de Nascimento',
    'situacao_seae': 'Situação',
  };

  final Map<String, String> _operators = {
    'igual a': '==',
    'diferente de': '!=',
    'contém': 'contém',
    'não contém': 'não contém',
    'começa com': 'começa com',
    'maior que': '>',
    'menor que': '<',
    'maior ou igual a': '>=',
    'menor ou igual a': '<=',
  };

  @override
  void initState() {
    super.initState();
    _loadDependencies();
  }

  Future<void> _loadDependencies() async {
    final situacoes = await _cadastroService.getSituacoes();
    if (mounted) {
      setState(() {
        _situacoesMap = situacoes;
      });
    }
  }

  String _getCellValue(Membro membro, String field) {
    switch (field) {
      case 'nome':
        return membro.nome;
      case 'dados_pessoais.cpf':
        return membro.dadosPessoais.cpf;
      case 'dados_pessoais.cidade':
        return membro.dadosPessoais.cidade;
      case 'data_proposta':
        return membro.dataProposta;
      case 'ultima_atualizacao':
        return membro.dataAtualizacao;
      case 'contribuicao':
        return membro.contribuicao.keys.join(', ');
      case 'atividades': // Corrigido
        return membro.atividades.join(', ');
      case 'dados_pessoais.data_nascimento':
        return membro.dadosPessoais.dataNascimento;
      case 'situacao_seae':
        return _situacoesMap[membro.situacaoSEAE.toString()] ?? 'N/D';
      default:
        return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consulta Avançada'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _resultados.isNotEmpty ? _gerarPdf : null,
          ),
        ],
      ),
      body: Padding(
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: filter.field,
                        decoration: const InputDecoration(labelText: 'Campo'),
                        items: _availableFields.keys.map((String key) {
                          return DropdownMenuItem<String>(
                            value: key,
                            child: Text(_availableFields[key]!),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            filter.field = newValue!;
                            filter.operator = _operators.values.first; // Resetar operador
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: filter.operator,
                        decoration: const InputDecoration(labelText: 'Operador'),
                        items: _operators.keys.map((String key) {
                          return DropdownMenuItem<String>(
                            value: _operators[key]!,
                            child: Text(key),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            filter.operator = newValue!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: TextEditingController(text: filter.value),
                        decoration: InputDecoration(labelText: 'Valor'),
                        onChanged: (String newValue) {
                          filter.value = newValue;
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle),
                      onPressed: _filters.length > 1 ? () => _removeFilter(idx) : null,
                    ),
                  ],
                ),
              );
            }),
            if (_filters.length < 5)
              TextButton.icon(
                onPressed: _addFilter,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar Filtro'),
              ),
          ],
        ),
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
          spacing: 8.0,
          runSpacing: 4.0,
          children: _availableFields.entries.map((entry) {
            final field = entry.key;
            final label = entry.value;
            final isSelected = _activeColumns.contains(field);
            final isDefault = field == 'nome' || field == 'dados_pessoais.cpf';
            return FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: isDefault ? null : (bool selected) {
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
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _performSearch,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Buscar'),
        ),
      ],
    );
  }

  Widget _buildResultsSection() {
    return Expanded(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _resultados.isEmpty
          ? const Center(child: Text('Nenhum resultado encontrado. Realize uma busca.'))
          : SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
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
        ),
      ),
    );
  }

  void _addFilter() {
    setState(() {
      _filters.add(Filter(field: _availableFields.keys.first, value: ''));
    });
  }

  void _removeFilter(int index) {
    setState(() {
      _filters.removeAt(index);
    });
  }

  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allMembers = await _cadastroService.getMembros().first;
      final results = allMembers.where((membro) {
        return _filters.every((filter) {
          final value = _getFieldValue(membro, filter.field);
          return _checkCondition(value, filter.operator, filter.value);
        });
      }).toList();

      setState(() {
        _resultados = results;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  dynamic _getFieldValue(Membro membro, String field) {
    switch (field) {
      case 'nome':
        return membro.nome;
      case 'dados_pessoais.cpf':
        return membro.dadosPessoais.cpf;
      case 'dados_pessoais.cidade':
        return membro.dadosPessoais.cidade;
      case 'data_proposta':
        return membro.dataProposta;
      case 'ultima_atualizacao':
        return membro.dataAtualizacao;
      case 'contribuicao':
        return membro.contribuicao;
      case 'atividades':
        return membro.atividades;
      case 'dados_pessoais.data_nascimento':
        return membro.dadosPessoais.dataNascimento;
      case 'situacao_seae':
        return membro.situacaoSEAE;
      default:
        return null;
    }
  }

  bool _checkCondition(dynamic fieldValue, String operator, String filterValue) {
    if (fieldValue == null) return false;

    switch (operator) {
      case '==':
        if (fieldValue is List) {
          return fieldValue.any((item) => item.toString().toLowerCase() == filterValue.toLowerCase());
        }
        return fieldValue.toString().toLowerCase() == filterValue.toLowerCase();
      case '!=':
        if (fieldValue is List) {
          return !fieldValue.any((item) => item.toString().toLowerCase() == filterValue.toLowerCase());
        }
        return fieldValue.toString().toLowerCase() != filterValue.toLowerCase();
      case 'contém':
        if (fieldValue is List) {
          return fieldValue.any((item) => item.toString().toLowerCase().contains(filterValue.toLowerCase()));
        }
        return fieldValue.toString().toLowerCase().contains(filterValue.toLowerCase());
      case 'não contém':
        if (fieldValue is List) {
          return !fieldValue.any((item) => item.toString().toLowerCase().contains(filterValue.toLowerCase()));
        }
        return !fieldValue.toString().toLowerCase().contains(filterValue.toLowerCase());
      case 'começa com':
        if (fieldValue is List) {
          return fieldValue.any((item) => item.toString().toLowerCase().startsWith(filterValue.toLowerCase()));
        }
        return fieldValue.toString().toLowerCase().startsWith(filterValue.toLowerCase());
      case '>':
        if (fieldValue is String && DateTime.tryParse(fieldValue) != null) {
          return DateTime.parse(fieldValue).isAfter(DateTime.parse(filterValue));
        }
        return false;
      case '<':
        if (fieldValue is String && DateTime.tryParse(fieldValue) != null) {
          return DateTime.parse(fieldValue).isBefore(DateTime.parse(filterValue));
        }
        return false;
      default:
        return false;
    }
  }

  Future<void> _gerarPdf() async {
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

class Filter {
  String field;
  String operator;
  String value;

  Filter({required this.field, this.operator = '==', required this.value});
}