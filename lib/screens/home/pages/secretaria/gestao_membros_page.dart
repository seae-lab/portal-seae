import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/screens/models/membro.dart';
import 'package:projetos/services/cadastro_service.dart';
import 'widgets/membro_form_dialog.dart';

class GestaoMembrosPage extends StatefulWidget {
  const GestaoMembrosPage({super.key});
  @override
  State<GestaoMembrosPage> createState() => _GestaoMembrosPageState();
}

class _GestaoMembrosPageState extends State<GestaoMembrosPage> {
  final CadastroService _cadastroService = Modular.get<CadastroService>();
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _searchController
        .addListener(() => setState(() => _searchTerm = _searchController.text));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Membros'),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nome...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Membro>>(
        stream: _cadastroService.getMembros(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum membro cadastrado.'));
          }

          final filteredMembers = snapshot.data!
              .where((m) =>
              m.nome.toLowerCase().contains(_searchTerm.toLowerCase()))
              .toList();

          filteredMembers.sort((a, b) => a.nome.compareTo(b.nome));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredMembers.length,
            itemBuilder: (context, index) {
              final membro = filteredMembers[index];
              return MemberListItem(
                membro: membro,
                onEdit: () => _showMemberForm(membro: membro),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMemberForm(),
        tooltip: 'Adicionar Membro',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class MemberListItem extends StatelessWidget {
  final Membro membro;
  final VoidCallback onEdit;

  const MemberListItem({super.key, required this.membro, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final activities = membro.atividades.join(', ');
    final contributionStatus =
    membro.listaContribuintes ? 'Contribuinte' : 'Não Contribuinte';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          // Se a URL da foto não estiver vazia, usa NetworkImage
          backgroundImage:
          membro.foto.isNotEmpty ? NetworkImage(membro.foto) : null,
          // Se a URL estiver vazia, mostra um ícone de pessoa
          child: membro.foto.isEmpty ? const Icon(Icons.person) : null,
        ),
        title: Row(
          children: [
            Expanded(
                child: Text(membro.nome,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
            if (activities.isNotEmpty)
              Text(activities,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (activities.isNotEmpty)
              const Text(' | ',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text(contributionStatus,
                style: TextStyle(
                    fontSize: 12,
                    color: membro.listaContribuintes
                        ? Colors.green
                        : Colors.orange)),
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
                  _buildDetailRow('Endereço:', membro.dadosPessoais.endereco),
                  _buildDetailRow(
                      'Data de Nasc:', membro.dadosPessoais.dataNascimento),
                  _buildDetailRow('CPF:', membro.dadosPessoais.cpf),
                  const Divider(height: 20),
                  _buildSectionTitle('Situação Cadastral'),
                  _buildDetailRow('Data da Proposta:', membro.dataProposta),
                  _buildDetailRow('Aprovação CD:', membro.dataAprovacaoCD),
                  _buildDetailRow('Última Atualização:', membro.dataAtualizacao),
                  _buildDetailRow(
                      'Frequenta desde:', membro.frequentaSeaeDesde.toString()),
                  _buildDetailRow('Mediunidade Ostensiva:',
                      membro.mediunidadeOstensiva ? 'Sim' : 'Não'),
                  const Divider(height: 20),
                  _buildSectionTitle('Contribuições'),
                  if (membro.contribuicao.isEmpty)
                    const Text('Nenhum registro.'),
                  ...membro.contribuicao.entries
                      .map((e) =>
                      Text('${e.key}: ${e.value ? "Pago" : "Pendente"}'))
                      .toList(),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 14),
          children: [
            TextSpan(
                text: '$label ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value.isNotEmpty ? value : "N/A"),
          ],
        ),
      ),
    );
  }
}
