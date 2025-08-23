// ARQUIVO COMPLETO: lib/screens/dij/widgets/jovem_dij_form_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:projetos/models/jovem_dij_model.dart';
import 'package:projetos/services/cadastro_service.dart';

class JovemDijFormDialog extends StatefulWidget {
  final JovemDij? jovem;
  final Function(JovemDij) onSave;

  const JovemDijFormDialog({super.key, this.jovem, required this.onSave});

  @override
  State<JovemDijFormDialog> createState() => _JovemDijFormDialogState();
}

class _JovemDijFormDialogState extends State<JovemDijFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final CadastroService _cadastroService = Modular.get<CadastroService>();
  late JovemDij _formData;
  bool _isNew = true;

  final List<bool> _expansionPanelOpenState = [true, true, true];

  // Controllers
  late TextEditingController _cepController;
  late TextEditingController _enderecoController;
  late TextEditingController _bairroController;
  late TextEditingController _cidadeController;
  late TextEditingController _ufController;

  // Masks
  final _celularMask = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _dataMask = MaskTextInputFormatter(mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});
  final _cepMask = MaskTextInputFormatter(mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    _isNew = widget.jovem == null;
    _formData = widget.jovem ?? JovemDij(nome: '', ciclo: 'Primeiro Ciclo', dataCadastro: DateTime.now());

    _cepController = TextEditingController(text: _formData.cep)..addListener(_onCepChanged);
    _enderecoController = TextEditingController(text: _formData.endereco);
    _bairroController = TextEditingController(text: _formData.bairro);
    _cidadeController = TextEditingController(text: _formData.cidade);
    _ufController = TextEditingController(text: _formData.uf);
  }

  @override
  void dispose() {
    _cepController.dispose();
    _enderecoController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _ufController.dispose();
    super.dispose();
  }

  void _onCepChanged() {
    final cep = _cepMask.getUnmaskedText();
    if (cep.length == 8) {
      _fetchCep(cep);
    }
  }

  Future<void> _fetchCep(String cep) async {
    final address = await _cadastroService.fetchCep(cep);
    if (mounted && address.isNotEmpty) {
      setState(() {
        _enderecoController.text = address['endereco']!;
        _bairroController.text = address['bairro']!;
        _cidadeController.text = address['cidade']!;
        _ufController.text = address['uf']!;
        _formData.endereco = address['endereco'];
        _formData.bairro = address['bairro'];
        _formData.cidade = address['cidade'];
        _formData.uf = address['uf'];
      });
    }
  }

  void _salvar() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      widget.onSave(_formData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Adicionar Jovem' : 'Editar Jovem'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _salvar, tooltip: 'Salvar'),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ExpansionPanelList(
            expansionCallback: (int index, bool isExpanded) {
              setState(() => _expansionPanelOpenState[index] = !isExpanded);
            },
            children: [
              _buildDadosJovemPanel(),
              _buildEnderecoPanel(),
              _buildFiliacaoPanel(),
            ],
          ),
        ),
      ),
    );
  }

  ExpansionPanel _buildDadosJovemPanel() {
    return ExpansionPanel(
      isExpanded: _expansionPanelOpenState[0],
      headerBuilder: (c, isOpen) => const ListTile(title: Text('Informações do Jovem', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              initialValue: _formData.nome,
              decoration: const InputDecoration(labelText: 'Nome Completo'),
              validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
              onSaved: (v) => _formData.nome = v!,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _formData.ciclo,
              decoration: const InputDecoration(labelText: 'Ciclo'),
              items: ['Primeiro Ciclo', 'Segundo Ciclo', 'Terceiro Ciclo', 'Grupo de Pais']
                  .map((ciclo) => DropdownMenuItem(value: ciclo, child: Text(ciclo)))
                  .toList(),
              onChanged: (v) => setState(() => _formData.ciclo = v!),
              onSaved: (v) => _formData.ciclo = v!,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _formData.dataNascimento,
              decoration: const InputDecoration(labelText: 'Data de Nascimento'),
              inputFormatters: [_dataMask],
              onSaved: (v) => _formData.dataNascimento = v,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _formData.frequentaSeaeDesde?.toString(),
              decoration: const InputDecoration(labelText: 'Frequenta a SEAE desde (ano)'),
              keyboardType: TextInputType.number,
              onSaved: (v) => _formData.frequentaSeaeDesde = int.tryParse(v ?? ''),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _formData.celularJovem,
              decoration: const InputDecoration(labelText: 'Celular do Jovem'),
              inputFormatters: [_celularMask],
              onSaved: (v) => _formData.celularJovem = v,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _formData.emailJovem,
              decoration: const InputDecoration(labelText: 'Email do Jovem'),
              onSaved: (v) => _formData.emailJovem = v,
            ),
          ],
        ),
      ),
    );
  }

  ExpansionPanel _buildEnderecoPanel() {
    return ExpansionPanel(
      isExpanded: _expansionPanelOpenState[1],
      headerBuilder: (c, isOpen) => const ListTile(title: Text('Endereço', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _cepController,
              decoration: const InputDecoration(labelText: 'CEP'),
              inputFormatters: [_cepMask],
              keyboardType: TextInputType.number,
              onSaved: (v) => _formData.cep = v,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _enderecoController,
              decoration: const InputDecoration(labelText: 'Endereço (Rua, Quadra, Número)'),
              onSaved: (v) => _formData.endereco = v,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _formData.complemento,
              decoration: const InputDecoration(labelText: 'Complemento'),
              onSaved: (v) => _formData.complemento = v,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bairroController,
              decoration: const InputDecoration(labelText: 'Bairro'),
              onSaved: (v) => _formData.bairro = v,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _cidadeController,
                    decoration: const InputDecoration(labelText: 'Cidade'),
                    onSaved: (v) => _formData.cidade = v,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _ufController,
                    decoration: const InputDecoration(labelText: 'UF'),
                    onSaved: (v) => _formData.uf = v,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ExpansionPanel _buildFiliacaoPanel() {
    return ExpansionPanel(
      isExpanded: _expansionPanelOpenState[2],
      headerBuilder: (c, isOpen) => const ListTile(title: Text('Filiação e Contato', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              initialValue: _formData.nomePai,
              decoration: const InputDecoration(labelText: 'Nome do Pai'),
              onSaved: (v) => _formData.nomePai = v,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _formData.celularPai,
              decoration: const InputDecoration(labelText: 'Celular do Pai'),
              inputFormatters: [_celularMask],
              onSaved: (v) => _formData.celularPai = v,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _formData.emailPai,
              decoration: const InputDecoration(labelText: 'Email do Pai'),
              onSaved: (v) => _formData.emailPai = v,
            ),
            const Divider(height: 32),
            TextFormField(
              initialValue: _formData.nomeMae,
              decoration: const InputDecoration(labelText: 'Nome da Mãe'),
              onSaved: (v) => _formData.nomeMae = v,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _formData.celularMae,
              decoration: const InputDecoration(labelText: 'Celular da Mãe'),
              inputFormatters: [_celularMask],
              onSaved: (v) => _formData.celularMae = v,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _formData.emailMae,
              decoration: const InputDecoration(labelText: 'Email da Mãe'),
              onSaved: (v) => _formData.emailMae = v,
            ),
            const Divider(height: 32),
            TextFormField(
              initialValue: _formData.anotacoes,
              decoration: const InputDecoration(labelText: 'Anotações'),
              maxLines: 4,
              onSaved: (v) => _formData.anotacoes = v,
            ),
          ],
        ),
      ),
    );
  }
}