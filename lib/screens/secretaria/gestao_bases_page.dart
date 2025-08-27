import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/auth_service.dart';
import 'package:projetos/services/secretaria_service.dart';
import 'package:projetos/widgets/loading_overlay.dart';

// Main Page Widget
class GestaoBasesPage extends StatefulWidget {
  const GestaoBasesPage({super.key});

  @override
  State<GestaoBasesPage> createState() => _GestaoBasesPageState();
}

class _GestaoBasesPageState extends State<GestaoBasesPage> {
  bool _isProcessing = false;

  void _setProcessing(bool isProcessing) {
    if (mounted) {
      setState(() {
        _isProcessing = isProcessing;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Bases de Dados'),
      ),
      body: LoadingOverlay(
        isLoading: _isProcessing,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 1200;
            return GridView.count(
              crossAxisCount: isWide ? 2 : 1,
              padding: const EdgeInsets.all(16),
              childAspectRatio: isWide ? 1.3 : 1.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                PermissionsCard(setProcessing: _setProcessing),
                DepartamentosCard(setProcessing: _setProcessing),
                SituacoesCard(),
                MediunidadeCard(setProcessing: _setProcessing),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Helper function to show delete confirmation dialog
Future<bool?> _showDeleteConfirmationDialog(BuildContext context, String itemName) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirmar Exclusão'),
      content: Text('Tem certeza que deseja excluir "$itemName"? Essa ação será refletida em todos os membros.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Excluir', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}


// Permissions Card Widget
class PermissionsCard extends StatefulWidget {
  final Function(bool) setProcessing;
  const PermissionsCard({super.key, required this.setProcessing});

  @override
  State<PermissionsCard> createState() => _PermissionsCardState();
}

class _PermissionsCardState extends State<PermissionsCard> {
  final CadastroService _cadastroService = Modular.get<CadastroService>();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Permissões de Usuários', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  tooltip: 'Adicionar Permissão',
                  onPressed: () => _showPermissionDialog(),
                ),
              ],
            ),
            Expanded(
              child: StreamBuilder<List<QueryDocumentSnapshot>>(
                stream: _cadastroService.getPermissions(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Nenhuma permissão encontrada.'));
                  }

                  final permissions = snapshot.data!
                      .where((doc) => doc.id != 'jhoel.fiorese@seae.org.br' && doc.id != 'exemplos')
                      .toList();

                  return ListView.builder(
                    itemCount: permissions.length,
                    itemBuilder: (context, index) {
                      final doc = permissions[index];
                      final email = doc.id;
                      final roles = Map<String, dynamic>.from(doc.data() as Map);
                      final rolesString = _formatRoles(roles);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(email),
                          subtitle: Text(rolesString.isEmpty ? 'Nenhum papel' : rolesString),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showPermissionDialog(email: email, currentRoles: roles),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await _showDeleteConfirmationDialog(context, email);
                                  if (confirm == true) {
                                    widget.setProcessing(true);
                                    try {
                                      await _cadastroService.deletePermission(email);
                                    } catch (e) {
                                      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
                                    } finally {
                                      if(mounted) widget.setProcessing(false);
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPermissionDialog({String? email, Map<String, dynamic>? currentRoles}) async {
    final isEditing = email != null;
    final exemplosDoc = await _cadastroService.permissionsCollection.doc('exemplos').get();
    final exemplosData = exemplosDoc.data() as Map<String, dynamic>? ?? {};

    final Map<String, List<String>> nestedRoles = {};
    final List<String> topLevelRoles = [];

    exemplosData.forEach((key, value) {
      if (key != 'admin') {
        if (value is Map) {
          nestedRoles[key] = (value.keys.toList()).map((e) => e.toString()).toList()..sort();
        } else {
          topLevelRoles.add(key);
        }
      }
    });
    topLevelRoles.sort();

    final emailController = TextEditingController(text: email);
    final formKey = GlobalKey<FormState>();

    final Map<String, bool> rolesState = {};
    if (isEditing && currentRoles != null) {
      currentRoles.forEach((key, value) {
        if (value is bool) {
          rolesState[key] = value;
        } else if (value is Map) {
          value.forEach((subKey, subValue) {
            if (subValue is bool) {
              rolesState[subKey] = subValue;
            }
          });
        }
      });
    }


    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Editar Permissões' : 'Adicionar Permissão'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isEditing)
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: 'Email do Usuário'),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Email é obrigatório.';
                            if (!value.endsWith('@seae.org.br')) return 'O email deve ser @seae.org.br.';
                            return null;
                          },
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      const Divider(height: 20),

                      if(Modular.get<AuthService>().currentUserPermissions?.isAdmin ?? false)
                        CheckboxListTile(
                          title: const Text('admin'),
                          value: rolesState['admin'] == true,
                          onChanged: (val) => setDialogState(() => rolesState['admin'] = val!),
                        ),

                      ...topLevelRoles.map((role) => CheckboxListTile(
                        title: Text(role),
                        value: rolesState[role] == true,
                        onChanged: (val) => setDialogState(() => rolesState[role] = val!),
                      )),

                      ...nestedRoles.entries.map((entry) {
                        final mainRole = entry.key;
                        final subRoles = entry.value;

                        return ExpansionTile(
                          title: Text(mainRole),
                          childrenPadding: const EdgeInsets.only(left: 16),
                          initiallyExpanded: true,
                          children: [
                            ...subRoles.map((subRole) {
                              return CheckboxListTile(
                                title: Text(subRole, style: const TextStyle(fontSize: 14)),
                                value: rolesState[subRole] == true,
                                onChanged: (val) => setDialogState(() => rolesState[subRole] = val!),
                                dense: true,
                              );
                            })
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? true) {
                      final navigator = Navigator.of(context);
                      widget.setProcessing(true);

                      final rolesToSave = <String, bool>{};
                      rolesState.forEach((key, value) {
                        if (value == true) {
                          rolesToSave[key] = true;
                        }
                      });

                      await _cadastroService.savePermission(emailController.text, rolesToSave);

                      if(mounted){
                        widget.setProcessing(false);
                        navigator.pop();
                      }
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatRoles(Map<String, dynamic> roles) {
    final List<String> formattedRoles = [];
    roles.forEach((key, value) {
      if (value == true) {
        formattedRoles.add(key);
      } else if (value is Map) {
        final subRoles = value.entries
            .where((e) => e.value == true)
            .map((e) => e.key)
            .toList();
        if (subRoles.isNotEmpty) {
          formattedRoles.add('$key (${subRoles.join(', ')})');
        }
      }
    });
    return formattedRoles.join(', ');
  }
}

// Departments Card Widget
class DepartamentosCard extends StatefulWidget {
  final Function(bool) setProcessing;
  const DepartamentosCard({super.key, required this.setProcessing});

  @override
  State<DepartamentosCard> createState() => _DepartamentosCardState();
}

class _DepartamentosCardState extends State<DepartamentosCard> {
  final CadastroService _cadastroService = Modular.get<CadastroService>();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Departamentos', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  tooltip: 'Adicionar',
                  onPressed: () => _showAddOrEditDialog(),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _cadastroService.getDepartamentosMap(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Nenhum item em "Departamentos".'));
                  }

                  final data = snapshot.data!;
                  final sortedKeys = data.keys.toList()..sort();

                  return SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        dataTextStyle: const TextStyle(fontSize: 15),
                        columns: const [
                          DataColumn(label: Text('Sigla')),
                          DataColumn(label: Expanded(child: Text('Descrição'))),
                          DataColumn(label: Text('Ações')),
                        ],
                        rows: sortedKeys.map((key) {
                          final value = data[key]?.toString() ?? '';
                          return DataRow(cells: [
                            DataCell(Text(key)),
                            DataCell(Text(value)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _showAddOrEditDialog(isEditing: true, oldKey: key, oldValue: value)
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final confirm = await _showDeleteConfirmationDialog(context, '$key: $value');
                                      if (confirm == true) {
                                        widget.setProcessing(true);
                                        try {
                                          await _cadastroService.deleteDepartmentFromMembers(key);
                                          data.remove(key);
                                          await _cadastroService.saveDepartamentosMap(data);
                                          if (mounted) setState(() {});
                                        } catch(e) {
                                          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
                                        } finally {
                                          if(mounted) widget.setProcessing(false);
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOrEditDialog({bool isEditing = false, String? oldKey, String? oldValue}) {
    final keyController = TextEditingController(text: oldKey);
    final valueController = TextEditingController(text: oldValue);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar Departamento' : 'Adicionar Departamento'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: keyController,
                decoration: const InputDecoration(labelText: 'Sigla'),
                validator: (v) => v == null || v.isEmpty ? 'Sigla não pode ser vazia' : null,
              ),
              TextFormField(
                controller: valueController,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final navigator = Navigator.of(context);
                widget.setProcessing(true);
                final currentData = await _cadastroService.getDepartamentosMap();
                final newKey = keyController.text;

                try {
                  if(isEditing && oldKey != null && oldKey != newKey) {
                    await _cadastroService.updateDepartmentInMembers(oldKey, newKey);
                    currentData.remove(oldKey);
                  }
                  currentData[newKey] = valueController.text;
                  await _cadastroService.saveDepartamentosMap(currentData);
                  if(mounted) setState(() {});
                } catch (e) {
                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
                } finally {
                  if(mounted) {
                    widget.setProcessing(false);
                    navigator.pop();
                  }
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

// Situations Card Widget
class SituacoesCard extends StatefulWidget {
  const SituacoesCard({super.key});

  @override
  State<SituacoesCard> createState() => _SituacoesCardState();
}

class _SituacoesCardState extends State<SituacoesCard> {
  final CadastroService _cadastroService = Modular.get<CadastroService>();
  final List<String> _defaultSituacoesIds = ["1", "2", "3", "4", "5", "6", "7"];

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Situações', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  tooltip: 'Adicionar',
                  onPressed: () => _showAddSituacaoDialog(),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<Map<String, String>>(
                future: _cadastroService.getSituacoes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Nenhum item em "Situações".'));
                  }

                  final data = snapshot.data!;
                  final sortedKeys = data.keys.toList()..sort((a,b) => int.parse(a).compareTo(int.parse(b)));

                  return SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        dataTextStyle: const TextStyle(fontSize: 15),
                        columns: const [
                          DataColumn(label: Text('ID')),
                          DataColumn(label: Expanded(child: Text('Descrição'))),
                          DataColumn(label: Text('')),
                        ],
                        rows: sortedKeys.map((key) {
                          final value = data[key] ?? '';
                          final isDefault = _defaultSituacoesIds.contains(key);

                          return DataRow(cells: [
                            DataCell(Text(key)),
                            DataCell(Text(value)),
                            DataCell(
                              isDefault
                                  ? Container()
                                  : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _showEditSituacaoDialog(key, value)
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final confirm = await _showDeleteConfirmationDialog(context, '$key: $value');
                                      if (confirm == true) {
                                        data.remove(key);
                                        await _cadastroService.saveSituacoes(data);
                                        setState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSituacaoDialog() async {
    final valueController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final currentData = await _cadastroService.getSituacoes();
    final highestId = currentData.keys.map(int.parse).reduce((a, b) => a > b ? a : b);
    final nextId = (highestId + 1).toString();

    if(!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Situação'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Novo ID será: $nextId", style: const TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: valueController,
                decoration: const InputDecoration(labelText: 'Descrição'),
                validator: (v) => v == null || v.isEmpty ? 'Descrição não pode ser vazia' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final navigator = Navigator.of(context);
                currentData[nextId] = valueController.text;
                await _cadastroService.saveSituacoes(currentData);
                setState(() {});
                navigator.pop();
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showEditSituacaoDialog(String key, String currentValue) {
    final valueController = TextEditingController(text: currentValue);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Situação (ID: $key)'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: valueController,
            decoration: const InputDecoration(labelText: 'Descrição'),
            validator: (v) => v == null || v.isEmpty ? 'Descrição não pode ser vazia' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final navigator = Navigator.of(context);
                final currentData = await _cadastroService.getSituacoes();
                currentData[key] = valueController.text;
                await _cadastroService.saveSituacoes(currentData);
                setState(() {});
                navigator.pop();
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

// Mediunidade Card Widget
class MediunidadeCard extends StatefulWidget {
  final Function(bool) setProcessing;
  const MediunidadeCard({super.key, required this.setProcessing});

  @override
  State<MediunidadeCard> createState() => _MediunidadeCardState();
}

class _MediunidadeCardState extends State<MediunidadeCard> {
  final CadastroService _cadastroService = Modular.get<CadastroService>();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tipos de Mediunidade', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  tooltip: 'Adicionar',
                  onPressed: () => _showAddOrEditMediunidadeDialog(),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<List<String>>(
                future: _cadastroService.getTiposMediunidade(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Nenhum tipo de mediunidade encontrado.'));
                  }

                  final mediunidades = List<String>.from(snapshot.data!)..sort();

                  return ListView.builder(
                    itemCount: mediunidades.length,
                    itemBuilder: (context, index) {
                      final item = mediunidades[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(item),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showAddOrEditMediunidadeDialog(isEditing: true, oldValue: item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await _showDeleteConfirmationDialog(context, item);
                                  if (confirm == true) {
                                    widget.setProcessing(true);
                                    try {
                                      await _cadastroService.deleteMediunidadeFromMembers(item);
                                      mediunidades.remove(item);
                                      await _cadastroService.saveTiposMediunidadeList(mediunidades);
                                      if(mounted) setState(() {});
                                    } catch (e) {
                                      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
                                    } finally {
                                      if(mounted) widget.setProcessing(false);
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOrEditMediunidadeDialog({bool isEditing = false, String? oldValue}) {
    final valueController = TextEditingController(text: oldValue);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar Tipo de Mediunidade' : 'Adicionar Tipo de Mediunidade'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: valueController,
            decoration: const InputDecoration(labelText: 'Descrição'),
            validator: (v) => v == null || v.isEmpty ? 'Descrição não pode ser vazia' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final navigator = Navigator.of(context);
                final newValue = valueController.text;
                widget.setProcessing(true);

                try {
                  if(isEditing && oldValue != null && oldValue != newValue) {
                    await _cadastroService.updateMediunidadeInMembers(oldValue, newValue);
                  }

                  final list = await _cadastroService.getTiposMediunidade();
                  if(isEditing && oldValue != null){
                    final index = list.indexOf(oldValue);
                    if(index != -1){
                      list[index] = newValue;
                    }
                  } else if (!isEditing) {
                    list.add(newValue);
                  }

                  await _cadastroService.saveTiposMediunidadeList(list);
                  if(mounted) setState(() {});
                } catch(e) {
                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
                } finally {
                  if(mounted){
                    widget.setProcessing(false);
                    navigator.pop();
                  }
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}