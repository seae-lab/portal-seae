// lib/screens/secretaria/relatorios/colaboradores_departamento_page.dart

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
import '../../../services/secretaria_service.dart';

class ColaboradoresDepartamentoPage extends StatefulWidget {
  const ColaboradoresDepartamentoPage({super.key});

  @override
  State<ColaboradoresDepartamentoPage> createState() => _ColaboradoresDepartamentoPageState();
}

class _ColaboradoresDepartamentoPageState extends State<ColaboradoresDepartamentoPage> {
  final CadastroService _cadastroService = Modular.get<CadastroService>();
  Map<String, List<Membro>> _colaboradoresPorDepto = {};
  Map<String, String> _situacoesMap = {};
  bool _isLoading = true;
  String? _error;
  bool _isGeneratingPdf = false;


  static const List<int> idsSituacoesIncluidas = [2, 3, 4];

  // Map para mapear chaves de campos para nomes de colunas
  final Map<String, String> _availableFields = {
    'nome': 'Nome',
    'dados_pessoais.cpf': 'CPF',
    'situacao_nome': 'Situação',
    'data_proposta': 'Data de Proposta',
  };
  final Set<String> _activeColumns = {'nome', 'situacao_nome'};

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
      await _loadSituacoes();
      await _loadMembros();
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar as situações: $e';
        });
      }
    }
  }

  Future<void> _loadMembros() async {
    try {
      final todosMembros = await _cadastroService.getMembros().first;
      final colaboradores = todosMembros.where((membro) {
        // Corrigido: Usando 'atividades' em vez de 'departamentos'
        return membro.atividades.isNotEmpty && idsSituacoesIncluidas.contains(membro.situacaoSEAE);
      }).toList();

      final Map<String, List<Membro>> tempMap = {};
      for (final membro in colaboradores) {
        // Corrigido: Usando 'atividades' em vez de 'departamentos'
        for (final depto in membro.atividades) {
          tempMap.putIfAbsent(depto, () => []).add(membro);
        }
      }

      tempMap.forEach((key, value) {
        value.sort((a, b) => a.nome.compareTo(b.nome));
      });

      if (mounted) {
        setState(() {
          _colaboradoresPorDepto = tempMap;
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

  String _getCellValue(Membro membro, String field) {
    switch (field) {
      case 'nome':
        return membro.nome;
      case 'dados_pessoais.cpf':
        return membro.dadosPessoais.cpf;
      case 'situacao_nome':
        return _situacoesMap[membro.situacaoSEAE.toString()] ?? 'N/A';
      case 'data_proposta':
        return membro.dataProposta;
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
        build: (context) => _buildContent(context),
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
          title: const Text('Colaboradores por Departamento'),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _colaboradoresPorDepto.isNotEmpty && !_isGeneratingPdf
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
    if (_colaboradoresPorDepto.isEmpty && !_isLoading) return const Center(child: Text('Nenhum colaborador encontrado para os departamentos.'));

    final deptosOrdenados = _colaboradoresPorDepto.keys.toList()..sort();

    return Column(
      children: [
        _buildColumnSelection(),
        Expanded(
          child: ListView.builder(
            itemCount: deptosOrdenados.length,
            itemBuilder: (context, index) {
              final depto = deptosOrdenados[index];
              final colaboradores = _colaboradoresPorDepto[depto]!;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$depto (${colaboradores.length} membros)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: _activeColumns.map((field) {
                          return DataColumn(label: Text(_availableFields[field] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)));
                        }).toList(),
                        rows: colaboradores.map((membro) {
                          return DataRow(cells: _activeColumns.map((field) {
                            return DataCell(Text(_getCellValue(membro, field)));
                          }).toList());
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
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
              final isDefault = field == 'nome';

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
                    pw.Text('Relação de Colaboradores por Departamento', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, font: font)),
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

  List<pw.Widget> _buildContent(pw.Context context) {
    final deptosOrdenados = _colaboradoresPorDepto.keys.toList()..sort();
    final List<pw.Widget> widgets = [];

    final tableHeaders = _activeColumns.map((field) => _availableFields[field] ?? 'N/A').toList();

    for (final depto in deptosOrdenados) {
      widgets.add(pw.Header(
        level: 1,
        text: '$depto (${_colaboradoresPorDepto[depto]!.length} membros)',
      ));

      final tableData = _colaboradoresPorDepto[depto]!.map((membro) {
        return _activeColumns.map((field) => _getCellValue(membro, field)).toList();
      }).toList();

      widgets.add(pw.TableHelper.fromTextArray(
        headers: tableHeaders,
        data: tableData,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 10),
        border: pw.TableBorder.all(),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      ));
      widgets.add(pw.SizedBox(height: 20));
    }
    return widgets;
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10.0),
      child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
    );
  }
}