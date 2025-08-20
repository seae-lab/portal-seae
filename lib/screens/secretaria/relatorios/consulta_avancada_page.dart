// lib/screens/home/pages/secretaria/consulta_avancada_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:projetos/services/cadastro_service.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:pdf/pdf.dart';
import '../../../models/membro.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

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

  final Map<String, String> _availableFields = {
    'nome': 'Nome',
    'dados_pessoais.cpf': 'CPF',
    'dados_pessoais.cidade': 'Cidade',
    'dados_pessoais.cep': 'CEP',
    'situacao_SEAE': 'Situação',
    'atividade': 'Atividade (Departamento)'
  };

  Map<String, String> _situacoesMap = {};

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

  void _addFilter() {
    if (_filters.length < 5) {
      setState(() {
        _filters.add(Filter(field: 'nome', value: ''));
      });
    }
  }

  void _removeFilter(int index) {
    setState(() {
      _filters.removeAt(index);
    });
  }

  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
      _resultados = [];
      _activeColumns.clear();
      _activeColumns.addAll(['nome', 'dados_pessoais.cpf']);
      for (var filter in _filters) {
        _activeColumns.add(filter.field);
      }
    });

    try {
      final allMembers = await _cadastroService.getMembros().first;

      List<Membro> filteredMembers = allMembers.where((membro) {
        return _filters.every((filter) {
          if (filter.value.isEmpty) return true;
          return _checkMatch(membro, filter);
        });
      }).toList();

      setState(() {
        _resultados = filteredMembers;
      });

    } catch (e) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao realizar a busca: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _checkMatch(Membro membro, Filter filter) {
    final lowerCaseFilter = filter.value.toLowerCase();
    switch (filter.field) {
      case 'nome':
        return membro.nome.toLowerCase().contains(lowerCaseFilter);
      case 'dados_pessoais.cpf':
        return membro.dadosPessoais.cpf.contains(filter.value);
      case 'dados_pessoais.cidade':
        return membro.dadosPessoais.cidade.toLowerCase().contains(lowerCaseFilter);
      case 'dados_pessoais.cep':
        return membro.dadosPessoais.cep.contains(filter.value);
      case 'situacao_SEAE':
        final idMatch = membro.situacaoSEAE.toString() == filter.value;
        final situacaoNome = _situacoesMap[membro.situacaoSEAE.toString()] ?? '';
        final nameMatch = situacaoNome.toLowerCase().contains(lowerCaseFilter);
        return idMatch || nameMatch;
      case 'atividade':
        return membro.atividades.any((act) => act.toLowerCase().contains(lowerCaseFilter));
      default:
        return false;
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
      case 'dados_pessoais.cep':
        return membro.dadosPessoais.cep;
      case 'situacao_SEAE':
        return _situacoesMap[membro.situacaoSEAE.toString()] ?? 'N/D';
      case 'atividade':
        return membro.atividades.join(', ');
      default:
        return 'N/A';
    }
  }

  Future<Uint8List> _buildPdfBytes() async {
    final pdf = pw.Document();
    final headers = _activeColumns.map((field) => _availableFields[field] ?? 'N/A').toList();
    final data = _resultados.map((membro) {
      return _activeColumns.map((field) => _getCellValue(membro, field)).toList();
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            text: 'Relatório de Consulta Avançada - SEAE',
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
        ..download = 'relatorio_seae.pdf';
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
        title: const Text('Consulta Avançada'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterSection(),
            const SizedBox(height: 24),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _performSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _resultados.isNotEmpty ? _generateAndDownloadPdf : null,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Gerar PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: 'Imprimir Relatório',
                  onPressed: _resultados.isNotEmpty ? _generateAndPrintPdf : null,
                ),
              ],
            ),
            const Divider(height: 32),
            _buildResultsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ..._filters.asMap().entries.map((entry) {
            int idx = entry.key;
            Filter filter = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: filter.field,
                      items: _availableFields.entries.map((e) {
                        return DropdownMenuItem(value: e.key, child: Text(e.value));
                      }).toList(),
                      onChanged: (value) {
                        if(value != null) {
                          setState(() {
                            _filters[idx].field = value;
                          });
                        }
                      },
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Campo'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      initialValue: filter.value,
                      onChanged: (value) {
                        _filters[idx].value = value;
                      },
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Valor a buscar'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
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
}

class Filter {
  String field;
  String value;
  Filter({required this.field, required this.value});
}