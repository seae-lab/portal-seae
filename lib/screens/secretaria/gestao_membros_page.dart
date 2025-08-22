// lib/screens/secretaria/gestao_membros_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/auth_service.dart';
import 'package:projetos/services/cadastro_service.dart';
import '../../models/membro.dart';
import 'widgets/membro_form_dialog.dart';
import 'package:projetos/widgets/loading_overlay.dart';

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

  List<String> _selectedStatus = []; // Unifica filtros de situação e contribuição
  List<String> _selectedDepartments = [];
  List<String> _selectedContributionYears = [];
  Future<_PageDependencies>? _dependenciesFuture;
  bool _isLoading = true;

  // Chaves especiais para os filtros de status de contribuição
  static const String _emAtrasoKey = 'status_contribuicao_em_atraso';
  static const String _contribuinteKey = 'status_contribuicao_contribuinte';
  static const String _naoContribuinteKey = 'status_contribuicao_nao_contribuinte';


  @override
  void initState() {
    super.initState();
    _loadDependenciesAndMembers();
    _searchController.addListener(() => setState(() => _searchTerm = _searchController.text));
  }

  Future<void> _loadDependenciesAndMembers() async {
    try {
      final results = await Future.wait([
        _cadastroService.getSituacoes(),
        _cadastroService.getAnosContribuicao(),
        _cadastroService.getDepartamentos(),
      ]);
      if (mounted) {
        setState(() {
          _dependenciesFuture = Future.value(_PageDependencies(
            situacoes: results[0] as Map<String, String>,
            anosContribuicao: (results[1] as List<String>)..sort(),
            departamentos: results[2] as List<String>,
          ));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ({String text, Color color}) _getContributionStatusForMember(Membro membro) {
    final bool isSocioEfetivo = membro.situacaoSEAE == 4;

    if (!isSocioEfetivo) {
      return (text: 'Não Contribuinte', color: Colors.blue);
    }

    final int currentYear = DateTime.now().year;
    final String currentYearStr = currentYear.toString();
    final currentYearData = membro.contribuicao[currentYearStr];

    if (currentYearData is Map &&
        currentYearData['meses'] is Map &&
        (currentYearData['meses'] as Map).values.any((pago) => pago == true)) {
      return (text: 'Contribuinte', color: Colors.green);
    }

    return (text: 'Contribuição em Atraso', color: Colors.orange);
  }

  void _showMemberForm({Membro? membro}) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(child: MembroFormDialog(membro: membro)),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _loadDependenciesAndMembers();
        });
      }
    });
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
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: const Text('Excluir', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(ctx).pop();
                if (mounted) setState(() => _isLoading = true);
                try {
                  await _cadastroService.deleteMembro(membro.id!);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Membro "${membro.nome}" excluído com sucesso.'), backgroundColor: Colors.green));
                  }
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir membro: $error'), backgroundColor: Colors.red));
                  }
                } finally {
                  if (mounted) _loadDependenciesAndMembers();
                }
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
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: FutureBuilder<_PageDependencies>(
          future: _dependenciesFuture,
          builder: (context, dependenciesSnapshot) {
            if (dependenciesSnapshot.connectionState == ConnectionState.waiting && _isLoading) {
              return const SizedBox.shrink();
            }
            if (dependenciesSnapshot.hasError) {
              return Center(child: Text('Erro ao carregar dependências: ${dependenciesSnapshot.error}'));
            }
            if (!dependenciesSnapshot.hasData) {
              return const Center(child: Text('Dados de dependências não disponíveis.'));
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
                          hintText: 'Buscar por nome, CPF, e-mail...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildFilters(dependencies),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<Membro>>(
                    stream: _cadastroService.getMembros(),
                    builder: (context, membrosSnapshot) {
                      if (membrosSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (membrosSnapshot.hasError) {
                        return Center(child: Text('Erro ao carregar membros: ${membrosSnapshot.error}'));
                      }
                      if (!membrosSnapshot.hasData || membrosSnapshot.data!.isEmpty) {
                        return const Center(child: Text('Nenhum membro encontrado.'));
                      }

                      final allMembers = membrosSnapshot.data!;
                      final filteredMembers = allMembers.where((membro) {
                        final matchesSearchTerm = _searchTerm.isEmpty ||
                            membro.nome.toLowerCase().contains(_searchTerm.toLowerCase()) ||
                            membro.dadosPessoais.cpf.toLowerCase().contains(_searchTerm.toLowerCase()) ||
                            membro.dadosPessoais.email.toLowerCase().contains(_searchTerm.toLowerCase());

                        final statusIds = _selectedStatus.where((s) => !s.startsWith('status_contribuicao')).toList();
                        final contributionStatusFilters = _selectedStatus.where((s) => s.startsWith('status_contribuicao')).toList();

                        final memberStatus = _getContributionStatusForMember(membro);
                        bool matchesContributionStatus = contributionStatusFilters.isEmpty ||
                            (contributionStatusFilters.contains(_emAtrasoKey) && memberStatus.text == 'Contribuição em Atraso') ||
                            (contributionStatusFilters.contains(_contribuinteKey) && memberStatus.text == 'Contribuinte') ||
                            (contributionStatusFilters.contains(_naoContribuinteKey) && memberStatus.text == 'Não Contribuinte');

                        final matchesStatus = statusIds.isEmpty || statusIds.contains(membro.situacaoSEAE.toString());

                        final matchesDepartment = _selectedDepartments.isEmpty ||
                            _selectedDepartments.any((selectedDepto) =>
                                membro.atividades.any((depto) => depto.startsWith(selectedDepto)));

                        final matchesContributionYear = _selectedContributionYears.isEmpty ||
                            _selectedContributionYears.any((year) {
                              final contribuicaoAno = membro.contribuicao[year];
                              if (contribuicaoAno is Map) {
                                if (contribuicaoAno['quitado'] == true) return true;
                                final meses = contribuicaoAno['meses'] as Map<String, dynamic>?;
                                return meses != null && meses.values.any((pago) => pago == true);
                              }
                              return false;
                            });

                        return matchesSearchTerm && (matchesStatus && matchesContributionStatus) && matchesDepartment && matchesContributionYear;
                      }).toList();

                      filteredMembers.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

                      if (filteredMembers.isEmpty) {
                        return const Center(child: Text('Nenhum membro encontrado com os filtros selecionados.'));
                      }

                      return ListView.builder(
                        itemCount: filteredMembers.length,
                        itemBuilder: (context, index) {
                          final membro = filteredMembers[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: MemberListItem(
                              membro: membro,
                              onEdit: () => _showMemberForm(membro: membro),
                              onDelete: () => _deleteMember(membro),
                              canEdit: canEdit,
                              situacoes: dependencies.situacoes,
                              allAnosContribuicao: dependencies.anosContribuicao,
                              getContributionStatus: () => _getContributionStatusForMember(membro),
                            ),
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

  Widget _buildFilters(_PageDependencies dependencies) {
    return LayoutBuilder(
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
    );
  }

  Widget _buildStatusFilter(Map<String, String> situacoes) {
    final Map<String, String> allStatusOptions = {
      ...situacoes,
      _contribuinteKey: 'Contribuinte',
      _emAtrasoKey: 'Contribuição em Atraso',
      _naoContribuinteKey: 'Não Contribuinte',
    };

    return InkWell(
      onTap: () => _showMultiSelectDialog(
        title: 'Filtrar por Situação',
        options: allStatusOptions,
        selectedOptions: _selectedStatus,
        onConfirm: (values) {
          setState(() {
            _selectedStatus = values;
          });
        },
      ),
      child: InputDecorator(
        decoration: _filterDecoration().copyWith(labelText: 'Situação'),
        child: Text(_selectedStatus.isEmpty
            ? 'Todas as Situações'
            : '${_selectedStatus.length} Selecionada(s)'),
      ),
    );
  }

  Widget _buildDepartmentFilter(List<String> departamentos) {
    final mainDepartments = departamentos.map((d) => d.split('/').first).toSet().toList();

    return InkWell(
      onTap: () => _showManualAndMultiSelectDialog(
        title: 'Filtrar por Departamento',
        items: mainDepartments,
        selectedItems: _selectedDepartments,
        onConfirm: (values) {
          setState(() {
            _selectedDepartments = values;
          });
        },
      ),
      child: InputDecorator(
        decoration: _filterDecoration().copyWith(labelText: 'Departamento'),
        child: Text(_selectedDepartments.isEmpty
            ? 'Todos os Departamentos'
            : '${_selectedDepartments.length} Selecionado(s)'),
      ),
    );
  }

  Widget _buildContributionYearFilter(List<String> anos) {
    return InkWell(
      onTap: () => _showMultiSelectDialog(
        title: 'Filtrar por Ano de Contribuição',
        options: { for (var ano in anos) ano: ano },
        selectedOptions: _selectedContributionYears,
        onConfirm: (values) {
          setState(() {
            _selectedContributionYears = values;
          });
        },
      ),
      child: InputDecorator(
        decoration: _filterDecoration().copyWith(labelText: 'Ano Contribuição'),
        child: Text(_selectedContributionYears.isEmpty
            ? 'Qualquer Ano'
            : '${_selectedContributionYears.length} Selecionado(s)'),
      ),
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

  void _showManualAndMultiSelectDialog({
    required String title,
    required List<String> items,
    required List<String> selectedItems,
    required Function(List<String>) onConfirm,
  }) {
    final TextEditingController newDepartmentController = TextEditingController();
    List<String> allItems = items.toSet().toList()..sort();
    final List<String> tempSelected = [...selectedItems];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final List<String> combinedItems = [...allItems, ...tempSelected].toSet().toList()..sort();
            final List<String> visibleItems = combinedItems.where((item) => item.toLowerCase().contains(newDepartmentController.text.toLowerCase())).toList();

            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: newDepartmentController,
                      decoration: InputDecoration(
                        labelText: 'Digitar novo departamento',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            final newDepartment = newDepartmentController.text.trim();
                            if (newDepartment.isNotEmpty) {
                              setDialogState(() {
                                if (!tempSelected.contains(newDepartment)) {
                                  tempSelected.add(newDepartment);
                                }
                                newDepartmentController.clear();
                              });
                            }
                          },
                        ),
                      ),
                      onSubmitted: (value) {
                        final newDepartment = value.trim();
                        if (newDepartment.isNotEmpty && !tempSelected.contains(newDepartment)) {
                          setDialogState(() {
                            tempSelected.add(newDepartment);
                            newDepartmentController.clear();
                          });
                        }
                      },
                      onChanged: (_) => setDialogState((){}),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 250,
                      width: 300,
                      child: ListView(
                        shrinkWrap: true,
                        children: visibleItems.map((item) {
                          final isSelected = tempSelected.contains(item);
                          return CheckboxListTile(
                            title: Text(item),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  tempSelected.add(item);
                                } else {
                                  tempSelected.remove(item);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
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
    ).then((_) {
      newDepartmentController.dispose();
    });
  }

  void _showMultiSelectDialog({
    required String title,
    required Map<String, String> options,
    required List<String> selectedOptions,
    required Function(List<String>) onConfirm,
  }) {
    final List<String> tempSelected = [...selectedOptions];
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: ListBody(
                  children: options.entries.map((entry) {
                    return CheckboxListTile(
                      value: tempSelected.contains(entry.key),
                      title: Text(entry.value),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (isChecked) {
                        setDialogState(() {
                          if (isChecked ?? false) {
                            tempSelected.add(entry.key);
                          } else {
                            tempSelected.remove(entry.key);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: <Widget>[
                TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()),
                ElevatedButton(child: const Text('Confirmar'), onPressed: () => Navigator.of(context).pop(tempSelected)),
              ],
            );
          },
        );
      },
    ).then((selected) {
      if (selected != null) {
        onConfirm(selected);
      }
    });
  }
}

class MemberListItem extends StatelessWidget {
  final Membro membro;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool canEdit;
  final Map<String, String> situacoes;
  final List<String> allAnosContribuicao;
  final ({String text, Color color}) Function() getContributionStatus;

  const MemberListItem({
    super.key,
    required this.membro,
    required this.onEdit,
    required this.onDelete,
    required this.canEdit,
    required this.situacoes,
    required this.allAnosContribuicao,
    required this.getContributionStatus,
  });

  @override
  Widget build(BuildContext context) {
    final activities = membro.atividades.join(', ');
    final contributionStatus = getContributionStatus();
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
                  if (membro.contribuicao.keys.isEmpty)
                    const Text('Nenhum ano de contribuição registrado.')
                  else
                    ...membro.contribuicao.keys.toList()
                        .where((year) => allAnosContribuicao.contains(year))
                        .toList()
                        .map((year) {
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
                                if (isQuitado) const Chip(label: Text('Ano Quitado'), backgroundColor: Colors.lightGreenAccent, padding: EdgeInsets.zero)
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
                                          border: Border.all(color: isPaid ? Colors.green : Colors.grey.shade300)),
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

class MultiSelectDialog extends StatefulWidget {
  final Map<String, String> items;
  final List<String> initialSelectedItems;
  final String title;

  const MultiSelectDialog({
    super.key,
    required this.items,
    required this.initialSelectedItems,
    required this.title,
  });

  @override
  State<MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<MultiSelectDialog> {
  late List<String> _selectedItems;

  @override
  void initState() {
    super.initState();
    _selectedItems = List<String>.from(widget.initialSelectedItems);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: ListBody(
          children: widget.items.entries.map((entry) {
            return CheckboxListTile(
              value: _selectedItems.contains(entry.key),
              title: Text(entry.value),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (isChecked) {
                setState(() {
                  if (isChecked ?? false) {
                    _selectedItems.add(entry.key);
                  } else {
                    _selectedItems.remove(entry.key);
                  }
                });
              },
            );
          }).toList(),
        ),
      ),
      actions: <Widget>[
        TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()),
        ElevatedButton(child: const Text('Confirmar'), onPressed: () => Navigator.of(context).pop(_selectedItems)),
      ],
    );
  }
}