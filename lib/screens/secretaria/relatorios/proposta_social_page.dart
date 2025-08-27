// lib/screens/secretaria/relatorios/proposta_social_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:projetos/models/membro.dart';
import 'package:projetos/services/secretaria_service.dart';
import 'package:projetos/widgets/loading_overlay.dart';
import 'package:flutter/services.dart';

class PropostaSocialPage extends StatefulWidget {
  const PropostaSocialPage({super.key});

  @override
  State<PropostaSocialPage> createState() => _PropostaSocialPageState();
}

class _PropostaSocialPageState extends State<PropostaSocialPage> {
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
          title: const Text('Gerar Proposta Social'),
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
              _buildMemberSearch(),
              const SizedBox(height: 24),
              Expanded(
                child: _selectedMember == null
                    ? const Center(child: Text('Selecione um membro para visualizar a proposta.'))
                    : _buildFormPreview(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberSearch() {
    return Autocomplete<Membro>(
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
        setState(() {
          _selectedMember = selection;
        });
        // Limpar o foco para esconder o teclado
        FocusScope.of(context).unfocus();
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
              labelText: 'Buscar Membro',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  textEditingController.clear();
                  setState(() {
                    _selectedMember = null;
                  });
                },
              )),
        );
      },
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
              'Proposta Social',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 30),
          _buildPreviewField('Nome', membro.nome),
          _buildPreviewField('CPF', membro.dadosPessoais.cpf),
          _buildPreviewField('Identidade', '${membro.dadosPessoais.rg} / ${membro.dadosPessoais.rgOrgaoExpedidor}'),
          _buildPreviewField('Data de Nascimento', membro.dadosPessoais.dataNascimento),
          _buildPreviewField('Endereço', '${membro.dadosPessoais.endereco}, ${membro.dadosPessoais.bairro}, ${membro.dadosPessoais.cidade} - ${membro.dadosPessoais.cep}'),
          _buildPreviewField('Celular', membro.dadosPessoais.celular),
          _buildPreviewField('E-mail', membro.dadosPessoais.email),
          _buildPreviewField('Profissão', membro.dadosPessoais.profissao),
          _buildPreviewField('Atividades na SEAE', membro.atividades.join(', ')),
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

  // --- Geração de PDF ---
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
              _buildPdfHeader(logoImage),
              _buildPdfFormTable(_selectedMember!),
              _buildPdfClauses(),
              pw.Spacer(),
              _buildPdfSignature(),
              _buildPdfFooter(),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (format) async => bytes);
    setState(() => _isGeneratingPdf = false);
  }

  pw.Widget _buildPdfHeader(pw.MemoryImage logo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Image(logo, width: 60),
        pw.SizedBox(width: 20),
        pw.Center(
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('SOCIEDADE ESPÍRITA DE ASSISTÊNCIA E ESTUDO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text('PROPOSTA SOCIAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
              ]),
        )
      ],
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

    return pw.Column(children: [
      pw.SizedBox(height: 15),
      pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1.5)},
        children: [
          pw.TableRow(children: [
            cell('Nome', m.nome),
            cell('CPF', m.dadosPessoais.cpf),
          ]),
        ],
      ),
      pw.Table(border: pw.TableBorder.all(), children: [
        pw.TableRow(children: [
          cell('Identidade', m.dadosPessoais.rg),
          cell('Órgão expedidor e UF', m.dadosPessoais.rgOrgaoExpedidor),
          cell('Sexo', m.dadosPessoais.sexo),
          cell('Data de Nascimento', m.dadosPessoais.dataNascimento),
          cell('Natural de (cidade e estado)', '${m.dadosPessoais.naturalidade} / ${m.dadosPessoais.naturalidadeUF}'),
        ])
      ]),
      pw.Table(border: pw.TableBorder.all(), children: [
        pw.TableRow(children: [
          cell('Estado Civil', m.dadosPessoais.estadoCivil),
          cell('Endereço', m.dadosPessoais.endereco),
          cell('Bairro', m.dadosPessoais.bairro),
          cell('Cidade', m.dadosPessoais.cidade),
          cell('CEP', m.dadosPessoais.cep),
        ]),
      ]),
      pw.Table(border: pw.TableBorder.all(), children: [
        pw.TableRow(children: [
          cell('Celular', m.dadosPessoais.celular),
          cell('Tel Residencial', m.dadosPessoais.telResidencia),
          cell('Tel Comercial', m.dadosPessoais.telComercial),
          cell('Profissão', m.dadosPessoais.profissao),
          cell('Local de Trabalho', m.dadosPessoais.localDeTrabalho),
        ]),
      ]),
      pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(2)},
        children: [
          pw.TableRow(children: [
            cell('E-mail', m.dadosPessoais.email),
            cell('Escolaridade', m.dadosPessoais.escolaridade),
          ]),
        ],
      ),
      pw.Table(border: pw.TableBorder.all(), children: [
        pw.TableRow(children: [
          cell('Frequenta a Seae desde quando?', m.frequentaSeaeDesde > 0 ? m.frequentaSeaeDesde.toString() : ''),
          pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
                checkbox('Tem mediunidade ostensiva?', m.mediunidadeOstensiva),
                cell('Qual?', m.tiposMediunidade.join(', ')),
              ])),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: checkbox('Já frequentou outras casas espíritas?', m.frequentouOutrosCentros)),
        ]),
        pw.TableRow(children: [
          cell('Grupos que participa na SEAE', m.atividades.join(', ')),
        ])
      ]),
    ]);
  }

  pw.Widget _buildPdfClauses() {
    return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(
            'O proponente acima qualificado solicita a sua inclusão no quadro de sócios da Sociedade Espírita de Assistência e Estudo – SEAE, comprometendo-se a: cumprir os deveres dos sócios definidos no Estatuto e no Regimento Interno em vigor na SEAE, dos quais declara ter pleno conhecimento; contribuir mensalmente para auxiliar na manutenção da instituição, com importância livremente fixada por ele próprio; aderir ao trabalho voluntário nos termos da Lei nº 9.608 de 18 de fevereiro de 1998 e nas condições definidas nas cláusulas do presente Termo de Adesão.',
            style: const pw.TextStyle(fontSize: 9),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 8),
          pw.Text('CLÁUSULA PRIMEIRA: O proponente tem conhecimento de que os serviços que por ele forem prestados à SEAE serão voluntários e não serão, sob qualquer hipótese, remunerados nem gerarão vínculo empregatício nem obrigação de natureza trabalhista, previdenciária ou outras afins.', style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 4),
          pw.Text('CLÁUSULA SEGUNDA: O proponente deverá observar, na execução do serviço em que estiver atuando, o Estatuto, o Regimento Interno e as demais normas da SEAE, bem como as orientações da Assembleia Geral, do Conselho Diretor, dos Departamentos e dos Órgãos Administrativos da SEAE.', style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 4),
          pw.Text('CLÁUSULA TERCEIRA: A SEAE ressarcirá ao proponente as despesas que ele comprovadamente houver realizado no desempenho de suas atividades, desde que haja prévia autorização do Presidente do Conselho Diretor para o reembolso.', style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 4),
          pw.Text('CLÁUSULA QUARTA: O proponente será responsável pelos danos e prejuízos que porventura vier a causar à SEAE, devendo ressarcir aqueles provenientes de dolo ou culpa.', style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 4),
          pw.Text('CLÁUSULA QUINTA: Fica eleito o foro de Brasília, Distrito Federal, para dirimir quaisquer dúvidas com relação a presente Proposta Social e Adesão de Serviço Voluntário, que para tanto firmam o presente.', style: const pw.TextStyle(fontSize: 8)),
        ]));
  }

  pw.Widget _buildPdfSignature() {
    final now = DateTime.now();
    return pw.Column(children: [
      pw.Text('Brasília, ${now.day} de ${DateFormat.MMMM('pt_BR').format(now)} de ${now.year}', textAlign: pw.TextAlign.right),
      pw.SizedBox(height: 40),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
        pw.SizedBox(
          width: 150,
          child: pw.Column(children: [
            pw.Divider(color: PdfColors.black),
            pw.Text('Proponente', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('CPF: ${_selectedMember!.dadosPessoais.cpf}', style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
        pw.SizedBox(
          width: 150,
          child: pw.Column(children: [
            pw.Divider(color: PdfColors.black),
            pw.Text('Sócio Subscritor', style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
      ]),
      pw.SizedBox(height: 30),
      pw.SizedBox(
        width: 200,
        child: pw.Column(children: [
          pw.Divider(color: PdfColors.black),
          pw.Text('Presidente do Conselho Diretor', style: const pw.TextStyle(fontSize: 9)),
        ]),
      ),
    ]);
  }

  pw.Widget _buildPdfFooter() {
    return pw.Column(children: [
      pw.SizedBox(height: 20),
      pw.Table(border: pw.TableBorder.all(), children: [
        pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Para Uso da Secretaria', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Data Proposta Original: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Data Aprovação no CD:', style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Número de Inscrição:', style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Data inclusão no Banco\nde Dados: ___/___/___', style: const pw.TextStyle(fontSize: 8))),
        ])
      ]),
      pw.SizedBox(height: 5),
      pw.Text('CNPJ 00.304.378/0001-89', style: const pw.TextStyle(fontSize: 7)),
      pw.Text('Cruzeiro Novo Quadra 1105 lote 1 CEP 70658-150 - Brasília-DF - Fone 3234-5220', style: const pw.TextStyle(fontSize: 7)),
      pw.Text('Utilidade Pública reconhecida pelo GDF - Dec. 6963 de 27/08/1982 e pela União Dec. 88488 de 07/07/1983', style: const pw.TextStyle(fontSize: 7)),
    ]);
  }
}