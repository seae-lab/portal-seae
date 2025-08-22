import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/auth_service.dart';
import 'package:projetos/services/cadastro_service.dart';
import 'package:projetos/widgets/loading_overlay.dart';

// Main Page Widget
class GestaoBasesPage extends StatelessWidget {
  const GestaoBasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Bases de Dados'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 1200;
          return GridView.count(
            crossAxisCount: isWide ? 2 : 1,
            padding: const EdgeInsets.all(16),
            childAspectRatio: isWide ? 1.3 : 1.2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: const [
              PermissionsCard(),
              DepartamentosCard(),
              SituacoesCard(),
              MediunidadeCard(),
            ],
          );
        },
      ),
    );
  }
}

// Permissions Card Widget
class PermissionsCard extends StatefulWidget {
  const PermissionsCard({super.key});

  @override
  State<PermissionsCard> createState() => _PermissionsCardState();
}

class _PermissionsCardState extends State<PermissionsCard> {
  final CadastroService _cadastroService = Modular.get<CadastroService>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Card(
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
                                  onPressed: () => _deleteEntry(
                                      context: context,
                                      itemName: email,
                                      onConfirm: () async {
                                        setState(() => _isLoading = true);
                                        await _cadastroService.deletePermission(email);
                                        if (mounted) {
                                          setState(() => _isLoading = false);
                                        }
                                      }),
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

    Map<String, dynamic> rolesState = isEditing ? Map<String, dynamic>.from(currentRoles!) : {};

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

                        if (rolesState[mainRole] is! Map) {
                          rolesState[mainRole] = <String, bool>{};
                        }
                        final Map<String, dynamic> subRolesState = rolesState[mainRole];

                        return ExpansionTile(
                          title: Text(mainRole),
                          childrenPadding: const EdgeInsets.only(left: 16),
                          initiallyExpanded: true,
                          children: [
                            CheckboxListTile(
                              title: const Text('secretaria (acesso geral)', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                              value: subRolesState['secretaria'] == true,
                              onChanged: (val) => setDialogState(() => subRolesState['secretaria'] = val!),
                              dense: true,
                            ),
                            ...subRoles.where((r) => r != 'secretaria').map((subRole) {
                              return CheckboxListTile(
                                title: Text(subRole, style: const TextStyle(fontSize: 14)),
                                value: subRolesState[subRole] == true,
                                onChanged: (val) => setDialogState(() => subRolesState[subRole] = val!),
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
                      setState(() => _isLoading = true);

                      rolesState.removeWhere((key, value) => value is Map && (value.values.every((v) => v == false || v == null)));

                      await _cadastroService.savePermission(emailController.text, rolesState);

                      if(mounted){
                        setState(() => _isLoading = false);
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
  const DepartamentosCard({super.key});

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
                                    onPressed: () => _deleteEntry(
                                      context: context,
                                      itemName: '$key: $value',
                                      onConfirm: () async {
                                        data.remove(key);
                                        await _cadastroService.saveDepartamentosMap(data);
                                        setState(() {}); // Força a reconstrução deste widget
                                      },
                                    ),
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
                final currentData = await _cadastroService.getDepartamentosMap();
                if(isEditing && oldKey != null && oldKey != keyController.text) {
                  currentData.remove(oldKey);
                }
                currentData[keyController.text] = valueController.text;
                await _cadastroService.saveDepartamentosMap(currentData);
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
                                    onPressed: () => _deleteEntry(
                                      context: context,
                                      itemName: '$key: $value',
                                      onConfirm: () async {
                                        data.remove(key);
                                        await _cadastroService.saveSituacoes(data);
                                        setState(() {});
                                      },
                                    ),
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
  const MediunidadeCard({super.key});

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
                                onPressed: () => _showAddOrEditMediunidadeDialog(isEditing: true, index: index, oldValue: item, currentList: mediunidades),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteEntry(
                                  context: context,
                                  itemName: item,
                                  onConfirm: () async {
                                    mediunidades.removeAt(index);
                                    await _cadastroService.saveTiposMediunidadeList(mediunidades);
                                    setState(() {});
                                  },
                                ),
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

  void _showAddOrEditMediunidadeDialog({bool isEditing = false, int? index, String? oldValue, List<String>? currentList}) {
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
                final list = isEditing ? currentList! : await _cadastroService.getTiposMediunidade();
                if(isEditing && index != null) {
                  list[index] = valueController.text;
                } else {
                  list.add(valueController.text);
                }
                await _cadastroService.saveTiposMediunidadeList(list);
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

// Funções Genéricas (movidas para fora das classes)
Future<void> _deleteEntry({
  required BuildContext context,
  required String itemName,
  required Future<void> Function() onConfirm,
}) async {
  final navigator = Navigator.of(context);
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirmar Exclusão'),
      content: Text('Tem certeza que deseja excluir "$itemName"?'),
      actions: [
        TextButton(onPressed: () => navigator.pop(false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => navigator.pop(true),
          child: const Text('Excluir', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  if (confirm == true) {
    try {
      await onConfirm();
    } catch (e) {
      if(scaffoldMessenger.mounted){
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
      }
    }
  }
}