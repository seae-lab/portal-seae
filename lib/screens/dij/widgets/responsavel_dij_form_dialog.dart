import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:projetos/models/jovem_dij_model.dart';
import 'package:projetos/services/secretaria_service.dart';

class ResponsavelDijFormDialog extends StatefulWidget {
  final JovemDij? jovem;
  final Function(JovemDij) onSave;

  const ResponsavelDijFormDialog({super.key, this.jovem, required this.onSave});

  @override
  State<ResponsavelDijFormDialog> createState() => _ResponsavelDijFormDialogState();
}

class _ResponsavelDijFormDialogState extends State<ResponsavelDijFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final CadastroService _cadastroService = Modular.get<CadastroService>();
  late JovemDij _formData;
  bool _isNew = true;

  final List<bool> _expansionPanelOpenState = [true, true, true];

  late TextEditingController _cepController;
  late TextEditingController _enderecoController;
  late TextEditingController _bairroController;
  late TextEditingController _cidadeController;
  late TextEditingController _ufController;

  final _celularMask = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _dataMask = MaskTextInputFormatter(mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});
  final _cepMask = MaskTextInputFormatter(mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    _isNew = widget.jovem == null;
    _formData = widget.jovem ?? JovemDij(nome: '', ciclo: 'Grupo de Pais', dataCadastro: DateTime.now());

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
        title: Text(_isNew ? 'Adicionar Responsável' : 'Editar Responsável'),
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
              _buildDadosResponsavelPanel(),
              _buildEnderecoPanel(),
              _buildFiliacaoPanel(),
            ],
          ),
        ),
      ),
    );
  }

  ExpansionPanel _buildDadosResponsavelPanel() {
    return ExpansionPanel(
      isExpanded: _expansionPanelOpenState[0],
      headerBuilder: (c, isOpen) => const ListTile(title: Text('Informações do Responsável', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              initialValue: _formData.nome,
              decoration: const InputDecoration(labelText: 'Nome Completo do Responsável'),
              validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
              onSaved: (v) => _formData.nome = v!,
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
              decoration: const InputDecoration(labelText: 'Celular do Responsável'),
              inputFormatters: [_celularMask],
              onSaved: (v) => _formData.celularJovem = v,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _formData.emailJovem,
              decoration: const InputDecoration(labelText: 'Email do Responsável'),
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
              decoration: const InputDecoration(labelText: 'Endereço'),
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
      headerBuilder: (c, isOpen) => const ListTile(title: Text('Filiação', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              initialValue: _formData.nomePai, // Reutilizando nomePai para o nome do filho
              decoration: const InputDecoration(labelText: 'Nome do Filho(a)'),
              onSaved: (v) {
                _formData.nomePai = v;
                _formData.nomeMae = null; // Limpa campos não utilizados
                _formData.celularPai = null;
                _formData.emailPai = null;
                _formData.celularMae = null;
                _formData.emailMae = null;
              },
            ),
            const SizedBox(height: 16),
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