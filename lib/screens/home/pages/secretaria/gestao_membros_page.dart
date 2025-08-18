import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/screens/models/membro.dart';
import 'package:projetos/services/auth_service.dart';
import 'package:projetos/services/cadastro_service.dart';
import 'widgets/membro_form_dialog.dart';

// Classe auxiliar para carregar dados necessários para a página
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

  // Estados para os novos filtros
  String? _selectedStatusId;
  String? _selectedDepartment;
  String? _selectedContributionYear;

  Future<_PageDependencies>? _dependenciesFuture;

  @override
  void initState() {
    super.initState();
    _dependenciesFuture ??= _loadDependencies();
    _searchController
        .addListener(() => setState(() => _searchTerm = _searchController.text));
  }

  Future<_PageDependencies> _loadDependencies() async {
    final results = await Future.wait([
      _cadastroService.getSituacoes(),
      _cadastroService.getAnosContribuicao(),
      _cadastroService.getDepartamentos(), // Carrega os departamentos
    ]);
    return _PageDependencies(
      situacoes: results[0] as Map<String, String>,
      anosContribuicao: results[1] as List<String>,
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
      builder: (context) =>
          Dialog.fullscreen(child: MembroFormDialog(membro: membro)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit = _authService.currentUserPermissions?.isAdmin ?? false;

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
            return const Center(child: Text('Erro ao carregar dependências.'));
          }

          final dependencies = dependenciesSnapshot.data!;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nome, atividade, ano, cidade...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Filtros em uma linha para telas largas, empilhados para telas estreitas
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
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
              Expanded(
                child: StreamBuilder<List<Membro>>(
                  stream: _cadastroService.getMembros(),
                  builder: (context, membrosSnapshot) {
                    if (membrosSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!membrosSnapshot.hasData ||
                        membrosSnapshot.data!.isEmpty) {
                      return const Center(
                          child: Text('Nenhum membro cadastrado.'));
                    }

                    final filteredMembers =
                    membrosSnapshot.data!.where((membro) {
                      final situacaoNome = dependencies.situacoes[membro.situacaoSEAE.toString()] ?? '';

                      // Lógica de filtro combinada
                      final statusMatch = _selectedStatusId == null ||
                          membro.situacaoSEAE.toString() == _selectedStatusId;

                      final departmentMatch = _selectedDepartment == null ||
                          membro.atividades.contains(_selectedDepartment);

                      final contributionMatch = _selectedContributionYear == null ||
                          (membro.contribuicao[_selectedContributionYear] ?? false);

                      final searchTermMatch = _searchTerm.isEmpty ||
                          membro.nome
                              .toLowerCase()
                              .contains(_searchTerm.toLowerCase()) ||
                          situacaoNome
                              .toLowerCase()
                              .contains(_searchTerm.toLowerCase()) ||
                          membro.atividades.any((a) => a
                              .toLowerCase()
                              .contains(_searchTerm.toLowerCase())) ||
                          membro.contribuicao.keys
                              .any((ano) => ano.contains(_searchTerm)) ||
                          membro.tiposMediunidade.any((t) => t
                              .toLowerCase()
                              .contains(_searchTerm.toLowerCase())) ||
                          membro.dadosPessoais.email
                              .toLowerCase()
                              .contains(_searchTerm.toLowerCase()) ||
                          membro.dadosPessoais.cpf.contains(_searchTerm) ||
                          membro.dadosPessoais.celular.contains(_searchTerm) ||
                          membro.dadosPessoais.endereco
                              .toLowerCase()
                              .contains(_searchTerm.toLowerCase()) ||
                          membro.dadosPessoais.bairro
                              .toLowerCase()
                              .contains(_searchTerm.toLowerCase()) ||
                          membro.dadosPessoais.cidade
                              .toLowerCase()
                              .contains(_searchTerm.toLowerCase());

                      return statusMatch && searchTermMatch && departmentMatch && contributionMatch;
                    }).toList();

                    filteredMembers.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: filteredMembers.length,
                      itemBuilder: (context, index) {
                        final membro = filteredMembers[index];
                        return MemberListItem(
                          membro: membro,
                          onEdit: () => _showMemberForm(membro: membro),
                          canEdit: canEdit,
                          situacoes: dependencies.situacoes,
                          allAnosContribuicao:
                          dependencies.anosContribuicao,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
        onPressed: () => _showMemberForm(),
        tooltip: 'Adicionar Membro',
        child: const Icon(Icons.add),
      )
          : null,
    );
  }

  // WIDGETS DE FILTRO REUTILIZÁVEIS
  Widget _buildStatusFilter(Map<String, String> situacoes) {
    return DropdownButtonFormField<String>(
      value: _selectedStatusId,
      hint: const Text('Situação...'),
      isExpanded: true,
      decoration: _filterDecoration(),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Todas as Situações')),
        ...situacoes.entries.map((entry) {
          return DropdownMenuItem<String>(value: entry.key, child: Text(entry.value));
        }).toList(),
      ],
      onChanged: (value) => setState(() => _selectedStatusId = value),
    );
  }

  Widget _buildDepartmentFilter(List<String> departamentos) {
    return DropdownButtonFormField<String>(
      value: _selectedDepartment,
      hint: const Text('Departamento...'),
      isExpanded: true,
      decoration: _filterDecoration(),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Todos os Departamentos')),
        ...departamentos.map((depto) {
          return DropdownMenuItem<String>(value: depto, child: Text(depto));
        }).toList(),
      ],
      onChanged: (value) => setState(() => _selectedDepartment = value),
    );
  }

  Widget _buildContributionYearFilter(List<String> anos) {
    return DropdownButtonFormField<String>(
      value: _selectedContributionYear,
      hint: const Text('Ano Contribuição...'),
      isExpanded: true,
      decoration: _filterDecoration(),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Qualquer Ano')),
        ...anos.map((ano) {
          return DropdownMenuItem<String>(value: ano, child: Text('Contribuiu em $ano'));
        }).toList(),
      ],
      onChanged: (value) => setState(() => _selectedContributionYear = value),
    );
  }

  InputDecoration _filterDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
  }
}

class MemberListItem extends StatelessWidget {
  final Membro membro;
  final VoidCallback onEdit;
  final bool canEdit;
  final Map<String, String> situacoes;
  final List<String> allAnosContribuicao;

  const MemberListItem({
    super.key,
    required this.membro,
    required this.onEdit,
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
      final year = int.parse(yearStr);
      final bool isPaid = membro.contribuicao[yearStr] ?? false;
      if (!isPaid && year < currentYear) {
        return (text: 'Contribuição em Atraso', color: Colors.orange);
      }
    }

    return (text: 'Contribuinte', color: Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    final activities = membro.atividades.join(', ');
    final contributionStatus = _getContributionStatus();
    final situacaoNome = situacoes[membro.situacaoSEAE.toString()] ?? '';
    final bool isMembroInativo = [5, 6, 7].contains(membro.situacaoSEAE);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundImage:
          membro.foto.isNotEmpty ? NetworkImage(membro.foto) : null,
          child: membro.foto.isEmpty ? const Icon(Icons.person) : null,
        ),
        title: Row(
          children: [
            Expanded(
                child: Text(membro.nome,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
            if (isMembroInativo) ...[
              if (situacaoNome.isNotEmpty)
                Text(situacaoNome,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.bold)),
            ] else ...[
              if (situacaoNome.isNotEmpty)
                Text(situacaoNome,
                    style:
                    const TextStyle(fontSize: 12, color: Colors.blueGrey)),
              if (situacaoNome.isNotEmpty)
                const Text(' | ',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              if (activities.isNotEmpty)
                Text(activities,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (activities.isNotEmpty)
                const Text(' | ',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(contributionStatus.text,
                  style: TextStyle(
                      fontSize: 12,
                      color: contributionStatus.color)),
            ],
            if (canEdit)
              IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit),
          ],
        ),
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
                  _buildDetailRow(
                      'Endereço:',
                      '${membro.dadosPessoais.endereco}, ${membro.dadosPessoais.bairro}, ${membro.dadosPessoais.cidade}'),
                  _buildDetailRow(
                      'Data de Nasc:', membro.dadosPessoais.dataNascimento),
                  _buildDetailRow('CPF:', membro.dadosPessoais.cpf),
                  const Divider(height: 20),
                  _buildSectionTitle('Situação Cadastral'),
                  _buildDetailRow('Data da Proposta:', membro.dataProposta),
                  _buildDetailRow('Aprovação CD:', membro.dataAprovacaoCD),
                  _buildDetailRow(
                      'Última Atualização:', membro.dataAtualizacao),
                  _buildDetailRow(
                      'Frequenta desde:',
                      membro.frequentaSeaeDesde > 0
                          ? membro.frequentaSeaeDesde.toString()
                          : 'N/A'),
                  _buildDetailRow('Mediunidade Ostensiva:',
                      membro.mediunidadeOstensiva ? 'Sim' : 'Não'),
                  const Divider(height: 20),
                  _buildSectionTitle('Contribuições'),
                  if (allAnosContribuicao.isEmpty)
                    const Text('Nenhum ano de contribuição configurado.')
                  else
                    ...allAnosContribuicao.map((year) {
                      final int currentYear = DateTime.now().year;
                      final int anoContribuicao = int.parse(year);
                      final bool isPago = membro.contribuicao[year] ?? false;

                      String statusText;
                      Color statusColor;

                      if (isPago) {
                        statusText = 'Pago';
                        statusColor = Colors.green;
                      } else {
                        final bool isSocio = [3, 4].contains(membro.situacaoSEAE);
                        if (isSocio &&
                            !isMembroInativo &&
                            anoContribuicao < currentYear) {
                          statusText = 'Atrasado';
                          statusColor = Colors.red;
                        } else {
                          statusText = 'Pendente';
                          statusColor = Colors.grey;
                        }
                      }

                      return _buildDetailRow(
                        '$year:',
                        statusText,
                        valueColor: statusColor,
                      );
                    }).toList(),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 4.0),
    child: Text(title,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.blueAccent)),
  );

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 14),
          children: [
            TextSpan(
                text: '$label ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
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
