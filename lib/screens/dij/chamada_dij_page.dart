// Conteúdo atualizado de ferrazt/pag-seae/pag-seae-f1ecfa12a567d6280aa4dbc6787d965af79b4a34/lib/screens/dij/chamada_dij_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';
import 'package:projetos/models/jovem_dij_model.dart';
import 'package:projetos/services/auth_service.dart';
import 'package:projetos/services/dij_service.dart';

class ChamadaDijPage extends StatefulWidget {
  const ChamadaDijPage({super.key});

  @override
  State<ChamadaDijPage> createState() => _ChamadaDijPageState();
}

class _ChamadaDijPageState extends State<ChamadaDijPage> {
  final DijService _dijService = Modular.get<DijService>();
  final AuthService _authService = Modular.get<AuthService>();
  DateTime _dataSelecionada = DateTime.now();
  String? _cicloSelecionado;

  final List<String> _todosOsCiclos = [
    'Primeiro Ciclo',
    'Segundo Ciclo',
    'Terceiro Ciclo',
    'Grupo de Pais',
    'Pós Juventude'
  ];
  List<String> _ciclosPermitidos = [];
  // NOVO: Variável para controlar a permissão de edição da data
  bool _podeAlterarData = false;

  @override
  void initState() {
    super.initState();
    _definirPermissoesECiclos();
  }

  void _definirPermissoesECiclos() {
    final permissions = _authService.currentUserPermissions;
    if (permissions == null) return;

    // Define se o usuário pode alterar a data
    _podeAlterarData = permissions.hasRole('admin') || permissions.hasRole('dij_diretora');

    if (permissions.hasRole('admin') || permissions.hasRole('dij') || permissions.hasRole('dij_diretora')) {
      _ciclosPermitidos = _todosOsCiclos;
    } else {
      _ciclosPermitidos = [];
      if (permissions.hasRole('dij_ciclo_1')) _ciclosPermitidos.add('Primeiro Ciclo');
      if (permissions.hasRole('dij_ciclo_2')) _ciclosPermitidos.add('Segundo Ciclo');
      if (permissions.hasRole('dij_ciclo_3')) _ciclosPermitidos.add('Terceiro Ciclo');
      if (permissions.hasRole('dij_grupo_pais')) _ciclosPermitidos.add('Grupo de Pais');
      if (permissions.hasRole('dij_pos_juventude')) _ciclosPermitidos.add('Pós Juventude');
    }

    if (_ciclosPermitidos.isNotEmpty) {
      _cicloSelecionado = _ciclosPermitidos.first;
    }
  }

  Future<void> _selecionarData(BuildContext context) async {
    final DateTime? data = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (data != null && data != _dataSelecionada) {
      setState(() {
        _dataSelecionada = data;
      });
    }
  }

  Future<void> _handleSave(Map<String, bool> presencasFinais) async {
    if (_cicloSelecionado == null) return;

    final chamadaExiste = await _dijService.checkChamadaExists(_dataSelecionada, _cicloSelecionado!);

    bool deveSalvar = true;
    if (chamadaExiste && context.mounted) {
      deveSalvar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Atenção'),
          content: const Text('Já existe uma chamada para este dia e ciclo. Deseja substituí-la?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Substituir'),
            ),
          ],
        ),
      ) ?? false;
    }

    if (deveSalvar) {
      _dijService.salvarChamada(
        data: _dataSelecionada,
        ciclo: _cicloSelecionado!,
        presencas: presencasFinais,
      ).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chamada para $_cicloSelecionado salva com sucesso!')),
        );
        setState(() {});
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar chamada: $error')),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chamada DIJ'),
        actions: [
          TextButton.icon(
            // ATUALIZADO: Habilita o clique apenas para quem tem permissão
            onPressed: _podeAlterarData ? () => _selecionarData(context) : null,
            icon: Icon(Icons.calendar_today, color: _podeAlterarData ? Colors.white : Colors.white54),
            label: Text(
              DateFormat('dd/MM/yyyy').format(_dataSelecionada),
              style: TextStyle(color: _podeAlterarData ? Colors.white : Colors.white54),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              value: _cicloSelecionado,
              decoration: const InputDecoration(
                labelText: 'Selecione o Ciclo',
                border: OutlineInputBorder(),
              ),
              items: _ciclosPermitidos.map((ciclo) {
                return DropdownMenuItem(value: ciclo, child: Text(ciclo));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _cicloSelecionado = value);
                }
              },
            ),
          ),
          Expanded(
            child: _cicloSelecionado == null
                ? const Center(child: Text('Nenhum ciclo selecionado ou permitido.'))
                : _buildListaChamada(_cicloSelecionado!, _dataSelecionada),
          ),
        ],
      ),
    );
  }

  Widget _buildListaChamada(String ciclo, DateTime data) {
    return FutureBuilder<Map<String, bool>>(
      future: _dijService.getChamadaDoDia(data, ciclo),
      builder: (context, snapshotChamada) {
        if (snapshotChamada.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final presencasIniciais = snapshotChamada.data ?? {};

        return StreamBuilder<List<JovemDij>>(
          stream: _dijService.getJovens(ciclo: ciclo),
          builder: (context, snapshotAlunos) {
            if (snapshotAlunos.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshotAlunos.hasError) {
              return Center(child: Text('Erro ao carregar jovens: ${snapshotAlunos.error}'));
            }
            if (!snapshotAlunos.hasData || snapshotAlunos.data!.isEmpty) {
              return Center(child: Text('Nenhum jovem cadastrado em "$ciclo".'));
            }

            final jovens = snapshotAlunos.data!;

            return _ChamadaListView(
              key: ValueKey("$ciclo-${data.toIso8601String()}"),
              jovens: jovens,
              presencasIniciais: presencasIniciais,
              onSave: _handleSave,
            );
          },
        );
      },
    );
  }
}

class _ChamadaListView extends StatefulWidget {
  final List<JovemDij> jovens;
  final Map<String, bool> presencasIniciais;
  final Function(Map<String, bool>) onSave;

  const _ChamadaListView({
    super.key,
    required this.jovens,
    required this.presencasIniciais,
    required this.onSave,
  });

  @override
  State<_ChamadaListView> createState() => _ChamadaListViewState();
}

class _ChamadaListViewState extends State<_ChamadaListView> {
  late Map<String, bool> _presencas;

  @override
  void initState() {
    super.initState();
    _presencas = {};
    for (var jovem in widget.jovens) {
      _presencas[jovem.id!] = widget.presencasIniciais[jovem.id] ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: widget.jovens.length,
            itemBuilder: (context, index) {
              final jovem = widget.jovens[index];
              return CheckboxListTile(
                title: Text(jovem.nome),
                value: _presencas[jovem.id] ?? false,
                onChanged: (bool? value) {
                  setState(() {
                    _presencas[jovem.id!] = value ?? false;
                  });
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () => widget.onSave(_presencas),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50)
            ),
            child: const Text('Salvar Chamada'),
          ),
        ),
      ],
    );
  }
}