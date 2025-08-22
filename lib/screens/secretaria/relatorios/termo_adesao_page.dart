// lib/screens/secretaria/relatorios/termo_adesao_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:projetos/models/membro.dart';
import 'package:projetos/services/cadastro_service.dart';
import 'package:projetos/widgets/loading_overlay.dart';
import 'package:flutter/services.dart';

class TermoAdesaoPage extends StatefulWidget {
  const TermoAdesaoPage({super.key});

  @override
  State<TermoAdesaoPage> createState() => _TermoAdesaoPageState();
}

class _TermoAdesaoPageState extends State<TermoAdesaoPage> {
  final CadastroService _cadastroService = Modular.get<CadastroService>();
  List<Membro> _allMembers = [];
  Membro? _selectedMember;
  bool _isLoading = true;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final members = await _cadastroService.getMembros().first;
      if (mounted) {
        setState(() {
          _allMembers = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar membros: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading || _isGeneratingPdf,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gerar Termo de Adesão'),
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Gerar PDF',
              onPressed: _selectedMember != null ? _gerarPdf : null,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Autocomplete<Membro>(
                displayStringForOption: (Membro option) => option.nome,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<Membro>.empty();
                  }
                  return _allMembers.where((Membro member) {
                    return member.nome.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (Membro selection) {
                  setState(() => _selectedMember = selection);
                  FocusScope.of(context).unfocus();
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                        labelText: 'Buscar Colaborador',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            textEditingController.clear();
                            setState(() => _selectedMember = null);
                          },
                        )
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _selectedMember == null
                    ? const Center(child: Text('Selecione um colaborador para visualizar o termo.'))
                    : _buildFormPreview(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormPreview() {
    final membro = _selectedMember!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Termo de Adesão ao Serviço Voluntário',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(height: 30),
          _buildPreviewField('Nome', membro.nome),
          _buildPreviewField('CPF', membro.dadosPessoais.cpf),
          _buildPreviewField('Identidade', '${membro.dadosPessoais.rg} / ${membro.dadosPessoais.rgOrgaoExpedidor}'),
          _buildPreviewField('Endereço', '${membro.dadosPessoais.endereco}, ${membro.dadosPessoais.bairro}, ${membro.dadosPessoais.cidade} - ${membro.dadosPessoais.cep}'),
          _buildPreviewField('Celular', membro.dadosPessoais.celular),
        ],
      ),
    );
  }

  Widget _buildPreviewField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text.rich(
        TextSpan(
          text: '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold),
          children: [
            TextSpan(
              text: value.isNotEmpty ? value : 'Não informado',
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _gerarPdf() async {
    if (_selectedMember == null) return;
    setState(() => _isGeneratingPdf = true);

    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    final logoImageBytes = await rootBundle.load('assets/images/logo_SEAE_azul.png');
    final logoImage = pw.MemoryImage(logoImageBytes.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: ttf),
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Image(logoImage, width: 60),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('SOCIEDADE ESPÍRITA DE ASSISTÊNCIA E ESTUDO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                          pw.SizedBox(height: 5),
                          pw.Text('TERMO DE ADESÃO AO SERVIÇO VOLUNTÁRIO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                          pw.Text('Lei nº 9.608, de 18 de fevereiro de 1998', style: const pw.TextStyle(fontSize: 9)),
                        ]
                    ),
                  )
                ],
              ),
              pw.SizedBox(height: 20),
              pw.RichText(
                  textAlign: pw.TextAlign.justify,
                  text: pw.TextSpan(
                      style: const pw.TextStyle(fontSize: 10, height: 1.5),
                      children: [
                        const pw.TextSpan(text: 'Eu, '),
                        pw.TextSpan(text: _selectedMember!.nome, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        const pw.TextSpan(text: ', a seguir qualificado, solicito a minha inclusão no quadro de Colaboradores da Sociedade Espírita de Assistência e Estudo – SEAE, comprometendo-se a: cumprir as atribuições que me forem confiadas e respeitar o Estatuto e o Regimento Interno em vigor na SEAE, dos quais declaro ter pleno conhecimento; aderir ao trabalho voluntário nos termos da Lei nº 9.608 de 18 de fevereiro de 1998 e nas condições definidas nas cláusulas do presente Termo de Adesão.'),
                      ]
                  )
              ),
              pw.SizedBox(height: 15),
              pw.Text('CLÁUSULA PRIMEIRA: O proponente tem conhecimento de que os serviços que por ele forem prestados à SEAE serão voluntários e não serão, sob qualquer hipótese, remunerados nem gerarão vínculo empregatício nem obrigação de natureza trabalhista, previdenciária ou outras afins.', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 5),
              pw.Text('CLÁUSULA SEGUNDA: O proponente deverá observar, na execução do serviço em que estiver atuando, o Estatuto, o Regimento Interno e as demais normas da SEAE, bem como as orientações da Assembleia Geral, do Conselho Diretor, dos Departamentos e dos Órgãos Administrativos da SEAE.', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 5),
              pw.Text('CLÁUSULA TERCEIRA: A SEAE ressarcirá ao proponente as despesas que ele comprovadamente houver realizado no desempenho de suas atividades, desde que haja prévia autorização do Presidente do Conselho Diretor para o reembolso.', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 5),
              pw.Text('CLÁUSULA QUARTA: O proponente será responsável pelos danos e prejuízos que porventura vier a causar à SEAE, devendo ressarcir aqueles provenientes de dolo ou culpa.', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('Brasília, ${DateFormat("dd 'de' MMMM 'de' yyyy", 'pt_BR').format(DateTime.now())}')),
              pw.SizedBox(height: 50),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildSignatureLine('Proponente'),
                    _buildSignatureLine('Presidente Conselho Diretor'),
                  ]
              ),
              pw.Spacer(),
              _buildPdfFormTable(_selectedMember!), // Reutiliza a tabela do outro formulário
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => await pdf.save());
    if (mounted) {
      setState(() => _isGeneratingPdf = false);
    }
  }

  pw.Widget _buildSignatureLine(String text) {
    return pw.SizedBox(
      width: 200,
      child: pw.Column(
          children: [
            pw.Divider(color: PdfColors.black),
            pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
          ]
      ),
    );
  }

  pw.Widget _buildPdfFormTable(Membro m) {
    pw.Widget cell(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
            pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      );
    }

    pw.Widget checkbox(String label, bool checked) {
      return pw.Row(children: [
        pw.Container(
          width: 8,
          height: 8,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
          child: checked ? pw.Center(child: pw.Text('X', style: const pw.TextStyle(fontSize: 7))) : pw.Container(),
        ),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
      ]);
    }

    return pw.Column(
        children: [
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: { 0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1.5) },
            children: [
              pw.TableRow(children: [ cell('Nome', m.nome), cell('CPF', m.dadosPessoais.cpf), ]),
            ],
          ),
          pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(children: [
                  cell('Identidade', m.dadosPessoais.rg),
                  cell('Órgão expedidor e UF', m.dadosPessoais.rgOrgaoExpedidor),
                  cell('Sexo', m.dadosPessoais.sexo),
                  cell('Data de Nascimento', m.dadosPessoais.dataNascimento),
                  cell('Natural de (cidade e estado)', '${m.dadosPessoais.naturalidade} / ${m.dadosPessoais.naturalidadeUF}'),
                ])
              ]
          ),
          pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(children: [
                  cell('Estado Civil', m.dadosPessoais.estadoCivil),
                  cell('Endereço', m.dadosPessoais.endereco),
                  cell('Bairro', m.dadosPessoais.bairro),
                  cell('Cidade', m.dadosPessoais.cidade),
                  cell('CEP', m.dadosPessoais.cep),
                ]),
              ]
          ),
          pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(children: [
                  cell('Celular', m.dadosPessoais.celular),
                  cell('Tel Comercial', m.dadosPessoais.telComercial),
                  cell('Profissão', m.dadosPessoais.profissao),
                  cell('Local de Trabalho', m.dadosPessoais.localDeTrabalho),
                ]),
              ]
          ),
          pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(children: [
                  cell('E-mail', m.dadosPessoais.email),
                  cell('Escolaridade', m.dadosPessoais.escolaridade),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: checkbox('Já frequentou outras casas espíritas?', m.frequentouOutrosCentros)
                  ),
                ]),
                pw.TableRow(children: [
                  cell('Frequenta a Seae desde quando?', m.frequentaSeaeDesde > 0 ? m.frequentaSeaeDesde.toString() : ''),
                  cell('Grupos que participa na SEAE', m.atividades.join(', ')),
                ])
              ]
          ),
          pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child:  pw.Row(
                          children: [
                            checkbox('Tem mediunidade ostensiva?', m.mediunidadeOstensiva),
                            pw.SizedBox(width: 10),
                            cell('Qual?', m.tiposMediunidade.join(', ')),
                          ]
                      )
                  ),

                ])
              ]
          ),
          pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Para Uso da Secretaria', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Data Proposta Original: ___________', style: const pw.TextStyle(fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Número de Inscrição:', style: const pw.TextStyle(fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Data inclusão no Banco\nde Dados: ___/___/___', style: const pw.TextStyle(fontSize: 8))),
                ])
              ]
          ),
        ]
    );
  }
}