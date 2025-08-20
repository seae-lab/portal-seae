import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/auth_service.dart';
import 'package:projetos/services/cadastro_service.dart';
import '../../models/membro.dart';
import 'widgets/membro_form_dialog.dart';

class _PageDependencies {
  final Map<String, String> situacoes;
  final List<String> anosContribuicao;
  final List<String> departamentos;

  _PageDependencies({
    required this.situacoes,
    required this.anosContribuicao,
    required this.departamentos,
  });
}

class GestaoMembrosPage extends StatefulWidget {
  const GestaoMembrosPage({super.key});
  @override
  State<GestaoMembrosPage> createState() => _GestaoMembrosPageState();
}

class _GestaoMembrosPageState extends State<GestaoMembrosPage> {
  final CadastroService _cadastroService = Modular.get<CadastroService>();
  final AuthService _authService = Modular.get<AuthService>();
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  String? _selectedStatusId;
  String? _selectedDepartment;
  String? _selectedContributionYear;
  Future<_PageDependencies>? _dependenciesFuture;

  @override
  void initState() {
    super.initState();
    _dependenciesFuture ??= _loadDependencies();
    _searchController.addListener(() => setState(() => _searchTerm = _searchController.text));
  }

  Future<_PageDependencies> _loadDependencies() async {
    final results = await Future.wait([
      _cadastroService.getSituacoes(),
      _cadastroService.getAnosContribuicao(),
      _cadastroService.getDepartamentos(),
    ]);
    return _PageDependencies(
      situacoes: results[0] as Map<String, String>,
      anosContribuicao: (results[1] as List<String>)..sort(),
      departamentos: results[2] as List<String>,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMemberForm({Membro? membro}) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(child: MembroFormDialog(membro: membro)),
    ).then((_) => setState(() {
      _dependenciesFuture = _loadDependencies();
    }));
  }

  void _deleteMember(Membro membro) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: Text('Tem certeza que deseja excluir o membro "${membro.nome}"? Esta ação não pode ser desfeita.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
            TextButton(
              child: const Text('Excluir', style: TextStyle(color: Colors.red)),
              onPressed: () {
                _cadastroService.deleteMembro(membro.id!).then((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Membro "${membro.nome}" excluído com sucesso.'), backgroundColor: Colors.green)
                  );
                }).catchError((error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao excluir membro: $error'), backgroundColor: Colors.red)
                  );
                });
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit = _authService.currentUserPermissions?.hasRole('admin') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Membros'),
        centerTitle: false,
      ),
      body: FutureBuilder<_PageDependencies>(
        future: _dependenciesFuture,
        builder: (context, dependenciesSnapshot) {
          if (dependenciesSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (dependenciesSnapshot.hasError || !dependenciesSnapshot.hasData) {
            return Center(child: Text('Erro ao carregar dependências: ${dependenciesSnapshot.error}'));
          }
          final dependencies = dependenciesSnapshot.data!;
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nome, CPF, e-mail...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 700) {
                          return Row(
                            children: [
                              Expanded(child: _buildStatusFilter(dependencies.situacoes)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildDepartmentFilter(dependencies.departamentos)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildContributionYearFilter(dependencies.anosContribuicao)),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _buildStatusFilter(dependencies.situacoes),
                            const SizedBox(height: 8),
                            _buildDepartmentFilter(dependencies.departamentos),
                            const SizedBox(height: 8),
                            _buildContributionYearFilter(dependencies.anosContribuicao),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              StreamBuilder<List<Membro>>(
                stream: _cadastroService.getMembros(),
                builder: (context, membrosSnapshot) {
                  if (membrosSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!membrosSnapshot.hasData || membrosSnapshot.data!.isEmpty) {
                    return const Center(child: Text('Nenhum membro cadastrado.'));
                  }
                  final filteredMembers = membrosSnapshot.data!.where((membro) {
                    final statusMatch = _selectedStatusId == null || membro.situacaoSEAE.toString() == _selectedStatusId;
                    final departmentMatch = _selectedDepartment == null || membro.atividades.contains(_selectedDepartment);
                    final contributionMatch = () {
                      if (_selectedContributionYear == null) return true;
                      final anoData = membro.contribuicao[_selectedContributionYear];
                      if (anoData is Map) {
                        final mesesData = anoData['meses'];
                        if (mesesData is Map) return mesesData.values.any((pago) => pago == true);
                      }
                      return false;
                    }();
                    final searchTermMatch = _searchTerm.isEmpty ||
                        membro.nome.toLowerCase().contains(_searchTerm.toLowerCase()) ||
                        membro.dadosPessoais.email.toLowerCase().contains(_searchTerm.toLowerCase()) ||
                        membro.dadosPessoais.cpf.contains(_searchTerm);
                    return statusMatch && searchTermMatch && departmentMatch && contributionMatch;
                  }).toList();

                  filteredMembers.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

                  if (filteredMembers.isEmpty) {
                    return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('Nenhum membro encontrado com os filtros aplicados.')));
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: filteredMembers.map((membro) {
                        return MemberListItem(
                          membro: membro,
                          onEdit: () => _showMemberForm(membro: membro),
                          onDelete: () => _deleteMember(membro),
                          canEdit: canEdit,
                          situacoes: dependencies.situacoes,
                          allAnosContribuicao: dependencies.anosContribuicao,
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
        onPressed: () => _showMemberForm(),
        tooltip: 'Adicionar Membro',
        backgroundColor: const Color.fromRGBO(45, 55, 131, 1),
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
    );
  }

  Widget _buildStatusFilter(Map<String, String> situacoes) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedStatusId,
      hint: const Text('Situação...'),
      isExpanded: true,
      decoration: _filterDecoration(),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Todas as Situações')),
        ...situacoes.entries.map((entry) => DropdownMenuItem<String>(value: entry.key, child: Text(entry.value))),
      ],
      onChanged: (value) => setState(() => _selectedStatusId = value),
    );
  }

  Widget _buildDepartmentFilter(List<String> departamentos) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedDepartment,
      hint: const Text('Departamento...'),
      isExpanded: true,
      decoration: _filterDecoration(),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Todos os Departamentos')),
        ...departamentos.map((depto) => DropdownMenuItem<String>(value: depto, child: Text(depto))),
      ],
      onChanged: (value) => setState(() => _selectedDepartment = value),
    );
  }

  Widget _buildContributionYearFilter(List<String> anos) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedContributionYear,
      hint: const Text('Ano Contribuição...'),
      isExpanded: true,
      decoration: _filterDecoration(),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Qualquer Ano')),
        ...anos.map((ano) => DropdownMenuItem<String>(value: ano, child: Text('Contribuiu em $ano'))),
      ],
      onChanged: (value) => setState(() => _selectedContributionYear = value),
    );
  }

  InputDecoration _filterDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
  }
}

class MemberListItem extends StatelessWidget {
  final Membro membro;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool canEdit;
  final Map<String, String> situacoes;
  final List<String> allAnosContribuicao;

  const MemberListItem({
    super.key,
    required this.membro,
    required this.onEdit,
    required this.onDelete,
    required this.canEdit,
    required this.situacoes,
    required this.allAnosContribuicao,
  });

  ({String text, Color color}) _getContributionStatus() {
    final bool isSocio = [3, 4].contains(membro.situacaoSEAE);
    if (!isSocio) {
      return (text: 'Não Contribuinte', color: Colors.blue);
    }
    final int currentYear = DateTime.now().year;
    for (final yearStr in allAnosContribuicao) {
      final year = int.tryParse(yearStr) ?? 0;
      if (year < currentYear) {
        final anoData = membro.contribuicao[yearStr];
        if (anoData is Map && (anoData['quitado'] == null || anoData['quitado'] == false)) {
          final mesesData = anoData['meses'] as Map<String, dynamic>?;
          if (mesesData != null && mesesData.values.any((pago) => !pago)) {
            return (text: 'Contribuição em Atraso', color: Colors.orange);
          }
        }
      }
    }
    return (text: 'Contribuinte', color: Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    final activities = membro.atividades.join(', ');
    final contributionStatus = _getContributionStatus();
    final situacaoNome = situacoes[membro.situacaoSEAE.toString()] ?? 'Não definida';
    final bool isMembroInativo = [5, 6, 7].contains(membro.situacaoSEAE);
    final mesesAbrev = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final mesesLowerCase = ['janeiro', 'fevereiro', 'marco', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundImage: membro.foto.isNotEmpty ? NetworkImage(membro.foto) : null,
          child: membro.foto.isEmpty ? const Icon(Icons.person) : null,
        ),
        title: LayoutBuilder(
          builder: (context, constraints) {
            const breakpoint = 400.0;
            final showHorizontalLayout = constraints.maxWidth > breakpoint;

            final statusWidget = Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              alignment: showHorizontalLayout ? WrapAlignment.end : WrapAlignment.start,
              children: [
                if (isMembroInativo)
                  Text(situacaoNome, style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold))
                else ...[
                  if (situacaoNome.isNotEmpty)
                    Text(situacaoNome, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                  if (activities.isNotEmpty)
                    Text(activities, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(contributionStatus.text, style: TextStyle(fontSize: 12, color: contributionStatus.color)),
                ]
              ],
            );

            Widget titleContent;
            if (showHorizontalLayout) {
              titleContent = Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      membro.nome,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  statusWidget,
                ],
              );
            } else {
              titleContent = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    membro.nome,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  statusWidget,
                ],
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: titleContent,
            );
          },
        ),
        trailing: canEdit
            ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar Membro',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Excluir Membro',
              onPressed: onDelete,
            ),
          ],
        )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Dados Pessoais'),
                  _buildDetailRow('Email:', membro.dadosPessoais.email),
                  _buildDetailRow('Celular:', membro.dadosPessoais.celular),
                  _buildDetailRow('Endereço:', '${membro.dadosPessoais.endereco}, ${membro.dadosPessoais.bairro}, ${membro.dadosPessoais.cidade}'),
                  _buildDetailRow('Data de Nasc:', membro.dadosPessoais.dataNascimento),
                  _buildDetailRow('CPF:', membro.dadosPessoais.cpf),
                  const Divider(height: 20),
                  _buildSectionTitle('Situação Cadastral'),
                  _buildDetailRow('Data da Proposta:', membro.dataProposta),
                  _buildDetailRow('Aprovação CD:', membro.dataAprovacaoCD),
                  _buildDetailRow('Última Atualização:', membro.dataAtualizacao),
                  _buildDetailRow('Frequenta desde:', membro.frequentaSeaeDesde > 0 ? membro.frequentaSeaeDesde.toString() : 'N/A'),
                  _buildDetailRow('Mediunidade Ostensiva:', membro.mediunidadeOstensiva ? 'Sim' : 'Não'),
                  const Divider(height: 20),
                  _buildSectionTitle('Contribuições'),
                  if (allAnosContribuicao.isEmpty)
                    const Text('Nenhum ano de contribuição configurado.')
                  else
                    ...allAnosContribuicao.map((year) {
                      final anoData = membro.contribuicao[year] as Map<String, dynamic>? ?? {};
                      final isQuitado = anoData['quitado'] as bool? ?? false;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(year, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                if(isQuitado)
                                  const Chip(label: Text('Ano Quitado'), backgroundColor: Colors.lightGreenAccent, padding: EdgeInsets.zero)
                              ],
                            ),
                            const SizedBox(height: 4),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(12, (index) {
                                  final mesAbrev = mesesAbrev[index];
                                  final mesKey = mesesLowerCase[index];
                                  final isPaid = (anoData['meses'] as Map<String, dynamic>?)?[mesKey] ?? false;
                                  return Tooltip(
                                    message: isPaid ? 'Pago' : 'Pendente',
                                    child: Container(
                                      width: 28,
                                      margin: const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      decoration: BoxDecoration(
                                          color: isPaid ? Colors.green[100] : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: isPaid ? Colors.green : Colors.grey.shade300)
                                      ),
                                      child: Center(child: Text(mesAbrev, style: TextStyle(fontSize: 10, color: isPaid ? Colors.green[800] : Colors.grey[600]))),
                                    ),
                                  );
                                }),
                              ),
                            )
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)),
  );

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: value.isNotEmpty ? value : "N/A",
              style: TextStyle(color: valueColor),
            ),
          ],
        ),
      ),
    );
  }
}
