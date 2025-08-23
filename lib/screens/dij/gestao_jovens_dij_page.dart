// ARQUIVO COMPLETO: lib/screens/dij/gestao_jovens_dij_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/models/jovem_dij_model.dart';
import 'package:projetos/services/auth_service.dart';
import 'package:projetos/services/dij_service.dart';
import 'package:projetos/screens/dij/widgets/jovem_dij_form_dialog.dart';

class GestaoJovensDijPage extends StatefulWidget {
  const GestaoJovensDijPage({super.key});

  @override
  State<GestaoJovensDijPage> createState() => _GestaoJovensDijPageState();
}

class _GestaoJovensDijPageState extends State<GestaoJovensDijPage> {
  final AuthService _authService = Modular.get<AuthService>();
  final DijService _dijService = Modular.get<DijService>();
  final TextEditingController _searchController = TextEditingController();

  String _searchTerm = '';
  String? _cicloFiltro;

  List<String> _ciclosParaFiltro = ['Todos'];

  @override
  void initState() {
    super.initState();
    _definirFiltroInicial();
    _searchController.addListener(() {
      setState(() => _searchTerm = _searchController.text);
    });
  }

  void _definirFiltroInicial() {
    final permissions = _authService.currentUserPermissions;
    if (permissions == null) return;

    if (permissions.hasRole('dij_diretora') || permissions.hasRole('admin')) {
      _ciclosParaFiltro.addAll(['Primeiro Ciclo', 'Segundo Ciclo', 'Terceiro Ciclo', 'Grupo de Pais']);
      _cicloFiltro = 'Todos';
    } else {
      if (permissions.hasRole('dij_ciclo_1')) _ciclosParaFiltro.add('Primeiro Ciclo');
      if (permissions.hasRole('dij_ciclo_2')) _ciclosParaFiltro.add('Segundo Ciclo');
      if (permissions.hasRole('dij_ciclo_3')) _ciclosParaFiltro.add('Terceiro Ciclo');

      if(_ciclosParaFiltro.length == 2) {
        _ciclosParaFiltro.remove('Todos');
      }
      _cicloFiltro = _ciclosParaFiltro.isNotEmpty ? _ciclosParaFiltro.first : null;
    }
  }

  void _abrirFormulario([JovemDij? jovem]) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: JovemDijFormDialog(
          jovem: jovem,
          onSave: (jovemSalvo) {
            if (jovemSalvo.id != null) {
              _dijService.updateAluno(jovemSalvo);
            } else {
              _dijService.addAluno(jovemSalvo);
            }
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _confirmarExclusao(JovemDij jovem) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir ${jovem.nome}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              _dijService.deleteAluno(jovem.id!);
              Navigator.of(ctx).pop();
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Jovens - DIJ'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                if (_ciclosParaFiltro.length > 1)
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      value: _cicloFiltro,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        filled: true,
                      ),
                      items: _ciclosParaFiltro.map((ciclo) {
                        return DropdownMenuItem(value: ciclo, child: Text(ciclo));
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _cicloFiltro = value);
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<JovemDij>>(
              stream: _dijService.getAlunos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Nenhum jovem encontrado.'));
                }

                var jovens = snapshot.data!;

                if (_searchTerm.isNotEmpty) {
                  jovens = jovens.where((j) => j.nome.toLowerCase().contains(_searchTerm.toLowerCase())).toList();
                }
                if (_cicloFiltro != null && _cicloFiltro != 'Todos') {
                  jovens = jovens.where((j) => j.ciclo == _cicloFiltro).toList();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: jovens.length,
                  itemBuilder: (context, index) {
                    final jovem = jovens[index];
                    return JovemListItem(
                      jovem: jovem,
                      onEdit: () => _abrirFormulario(jovem),
                      onDelete: () => _confirmarExclusao(jovem),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormulario(),
        tooltip: 'Adicionar Jovem',
        backgroundColor: const Color.fromRGBO(45, 55, 131, 1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class JovemListItem extends StatelessWidget {
  final JovemDij jovem;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const JovemListItem({
    super.key,
    required this.jovem,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(jovem.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(jovem.ciclo),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: onDelete),
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
                  _buildDetailRow('Data de Nascimento:', jovem.dataNascimento ?? 'N/A'),
                  _buildDetailRow('Frequenta desde:', jovem.frequentaSeaeDesde?.toString() ?? 'N/A'),
                  _buildDetailRow('Celular:', jovem.celularJovem ?? 'N/A'),
                  _buildDetailRow('Email:', jovem.emailJovem ?? 'N/A'),
                  _buildDetailRow('Endereço:', jovem.endereco ?? 'N/A'),
                  const Divider(height: 20),
                  _buildDetailRow('Mãe:', jovem.nomeMae ?? 'N/A'),
                  _buildDetailRow('Celular da Mãe:', jovem.celularMae ?? 'N/A'),
                  _buildDetailRow('Email da Mãe:', jovem.emailMae ?? 'N/A'),
                  const Divider(height: 20),
                  _buildDetailRow('Pai:', jovem.nomePai ?? 'N/A'),
                  _buildDetailRow('Celular do Pai:', jovem.celularPai ?? 'N/A'),
                  _buildDetailRow('Email do Pai:', jovem.emailPai ?? 'N/A'),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 14),
          children: [
            TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}