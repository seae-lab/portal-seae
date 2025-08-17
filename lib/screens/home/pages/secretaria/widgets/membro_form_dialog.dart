import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:image_picker/image_picker.dart';
import 'package:projetos/screens/models/dados_pessoais.dart';
import 'package:projetos/screens/models/membro.dart';
import 'package:projetos/services/cadastro_service.dart';

class MembroFormDialog extends StatefulWidget {
  final Membro? membro;
  const MembroFormDialog({super.key, this.membro});

  @override
  State<MembroFormDialog> createState() => _MembroFormDialogState();
}

class _MembroFormDialogState extends State<MembroFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final CadastroService _cadastroService = Modular.get<CadastroService>();

  late Membro _formData;
  bool _isNewMember = true;
  bool _isSaving = false;
  Uint8List? _newImageBytes;

  final List<bool> _expansionPanelOpenState = [true, false, false, false];
  final _atividadeController = TextEditingController();
  final _anoContribuicaoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isNewMember = widget.membro == null;

    if (widget.membro != null) {
      // --- LÓGICA DE CLONAGEM CORRIGIDA ---
      // Garante que as listas e mapas sejam cópias modificáveis
      final m = widget.membro!;
      _formData = Membro(
        id: m.id, nome: m.nome, foto: m.foto,
        // Usa List.from() e Map.from() para criar cópias que podem ser alteradas
        atividades: List<String>.from(m.atividades),
        contribuicao: Map<String, bool>.from(m.contribuicao),
        dadosPessoais: DadosPessoais.fromMap(m.dadosPessoais.toMap()),
        // Copia os outros campos
        atualizacao: m.atualizacao, atualizacaoCD: m.atualizacaoCD, atualizacaoCF: m.atualizacaoCF,
        dataAprovacaoCD: m.dataAprovacaoCD, dataAtualizacao: m.dataAtualizacao, dataProposta: m.dataProposta,
        frequentaSeaeDesde: m.frequentaSeaeDesde, frequentouOutrosCentros: m.frequentouOutrosCentros,
        listaContribuintes: m.listaContribuintes, mediunidadeOstensiva: m.mediunidadeOstensiva,
        novoSocio: m.novoSocio, situacaoSEAE: m.situacaoSEAE, tipoMediunidade: m.tipoMediunidade,
        transfAutomatica: m.transfAutomatica,
      );
    } else {
      // --- CORREÇÃO PARA NOVO MEMBRO ---
      // Inicializa um membro vazio, mas com listas e mapas modificáveis
      _formData = Membro(
        id: '',
        nome: '',
        dadosPessoais: DadosPessoais(),
        atividades: [], // Inicializa com uma lista vazia modificável
        contribuicao: {}, // Inicializa com um mapa vazio modificável
      );
    }
  }

  @override
  void dispose() {
    _atividadeController.dispose();
    _anoContribuicaoController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _newImageBytes = bytes;
      });
    }
  }

  void _addAtividade() {
    if (_atividadeController.text.isNotEmpty) {
      setState(() => _formData.atividades.add(_atividadeController.text));
      _atividadeController.clear();
    }
  }

  void _addContribuicao() {
    if (_anoContribuicaoController.text.isNotEmpty) {
      setState(() =>
      _formData.contribuicao[_anoContribuicaoController.text] = false);
      _anoContribuicaoController.clear();
    }
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isSaving = true);

      try {
        if (_newImageBytes != null) {
          final imageUrl = await _cadastroService.uploadProfileImage(
            memberId: _formData.id,
            fileBytes: _newImageBytes!,
          );
          _formData.foto = imageUrl;
        }

        await _cadastroService.saveMembro(_formData);
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erro ao salvar: $e'),
                backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNewMember ? 'Adicionar Membro' : 'Editar Membro'),
        actions: [
          if (_isSaving)
            const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.white)),
          if (!_isSaving)
            IconButton(
                icon: const Icon(Icons.save), onPressed: _saveForm, tooltip: 'Salvar')
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // --- Seção de Upload de Foto ---
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _newImageBytes != null
                          ? MemoryImage(_newImageBytes!)
                          : (_formData.foto.isNotEmpty
                          ? NetworkImage(_formData.foto)
                          : null) as ImageProvider?,
                      child: _newImageBytes == null && _formData.foto.isEmpty
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Alterar Foto'),
                      onPressed: _pickImage,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ExpansionPanelList(
                expansionCallback: (int index, bool isExpanded) {
                  setState(() => _expansionPanelOpenState[index] = isExpanded);
                },
                children: [
                  _buildCadastroPanel(),
                  _buildDadosPessoaisPanel(),
                  _buildAtividadesPanel(),
                  _buildContribuicoesPanel(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  ExpansionPanel _buildCadastroPanel() {
    return ExpansionPanel(
      headerBuilder: (c, isOpen) => const ListTile(
          title: Text('Informações Cadastrais',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          if (_isNewMember)
            _buildTextField(
                label: 'ID (Ex: 2, 3...)',
                initialValue: _formData.id,
                onSaved: (v) => _formData.id = v!,
                isNumeric: true,
                isRequired: true),
          _buildTextField(
              label: 'Nome Completo',
              initialValue: _formData.nome,
              onSaved: (v) => _formData.nome = v!,
              isRequired: true),
          _buildTextField(
              label: 'Frequenta desde (ano)',
              initialValue: _formData.frequentaSeaeDesde > 0 ? _formData.frequentaSeaeDesde.toString() : '',
              onSaved: (v) =>
              _formData.frequentaSeaeDesde = int.tryParse(v!) ?? 0,
              isNumeric: true),
          _buildTextField(
              label: 'Situação SEAE (número)',
              initialValue: _formData.situacaoSEAE.toString(),
              onSaved: (v) => _formData.situacaoSEAE = int.tryParse(v!) ?? 0,
              isNumeric: true),
          _buildTextField(
              label: 'Tipo de Mediunidade',
              initialValue: _formData.tipoMediunidade,
              onSaved: (v) => _formData.tipoMediunidade = v!),
          _buildTextField(
              label: 'Data Proposta',
              initialValue: _formData.dataProposta,
              onSaved: (v) => _formData.dataProposta = v!),
          _buildTextField(
              label: 'Data Aprovação CD',
              initialValue: _formData.dataAprovacaoCD,
              onSaved: (v) => _formData.dataAprovacaoCD = v!),
          _buildTextField(
              label: 'Data Atualização',
              initialValue: _formData.dataAtualizacao,
              onSaved: (v) => _formData.dataAtualizacao = v!),
          _buildTextField(
              label: 'Atualização CD',
              initialValue: _formData.atualizacaoCD,
              onSaved: (v) => _formData.atualizacaoCD = v!),
          _buildTextField(
              label: 'Atualização CF',
              initialValue: _formData.atualizacaoCF,
              onSaved: (v) => _formData.atualizacaoCF = v!),
          _buildSwitch('Atualização?', _formData.atualizacao,
                  (val) => setState(() => _formData.atualizacao = val)),
          _buildSwitch(
              'Frequentou outros centros?',
              _formData.frequentouOutrosCentros,
                  (val) => setState(() => _formData.frequentouOutrosCentros = val)),
          _buildSwitch('Lista de Contribuintes?', _formData.listaContribuintes,
                  (val) => setState(() => _formData.listaContribuintes = val)),
          _buildSwitch(
              'Mediunidade Ostensiva?',
              _formData.mediunidadeOstensiva,
                  (val) => setState(() => _formData.mediunidadeOstensiva = val)),
          _buildSwitch('É novo sócio?', _formData.novoSocio,
                  (val) => setState(() => _formData.novoSocio = val)),
          _buildSwitch(
              'Transferência Automática?',
              _formData.transfAutomatica,
                  (val) => setState(() => _formData.transfAutomatica = val)),
        ]),
      ),
      isExpanded: _expansionPanelOpenState[0],
    );
  }

  ExpansionPanel _buildDadosPessoaisPanel() {
    return ExpansionPanel(
      headerBuilder: (c, isOpen) => const ListTile(
          title: Text('Dados Pessoais',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          _buildTextField(label: 'Email', initialValue: _formData.dadosPessoais.email, onSaved: (v) => _formData.dadosPessoais.email = v!),
          _buildTextField(label: 'Celular', initialValue: _formData.dadosPessoais.celular, onSaved: (v) => _formData.dadosPessoais.celular = v!),
          _buildTextField(label: 'Telefone Residencial', initialValue: _formData.dadosPessoais.telResidencia, onSaved: (v) => _formData.dadosPessoais.telResidencia = v!),
          _buildTextField(label: 'Telefone Comercial', initialValue: _formData.dadosPessoais.telComercial, onSaved: (v) => _formData.dadosPessoais.telComercial = v!),
          _buildTextField(label: 'Endereço', initialValue: _formData.dadosPessoais.endereco, onSaved: (v) => _formData.dadosPessoais.endereco = v!),
          _buildTextField(label: 'Bairro', initialValue: _formData.dadosPessoais.bairro, onSaved: (v) => _formData.dadosPessoais.bairro = v!),
          _buildTextField(label: 'Cidade', initialValue: _formData.dadosPessoais.cidade, onSaved: (v) => _formData.dadosPessoais.cidade = v!),
          _buildTextField(label: 'CEP', initialValue: _formData.dadosPessoais.cep, onSaved: (v) => _formData.dadosPessoais.cep = v!),
          _buildTextField(label: 'Data de Nascimento', initialValue: _formData.dadosPessoais.dataNascimento, onSaved: (v) => _formData.dadosPessoais.dataNascimento = v!),
          _buildTextField(label: 'CPF', initialValue: _formData.dadosPessoais.cpf, onSaved: (v) => _formData.dadosPessoais.cpf = v!),
          _buildTextField(label: 'RG', initialValue: _formData.dadosPessoais.rg, onSaved: (v) => _formData.dadosPessoais.rg = v!),
          _buildTextField(label: 'Orgão Exp. RG', initialValue: _formData.dadosPessoais.rgOrgaoExpedidor, onSaved: (v) => _formData.dadosPessoais.rgOrgaoExpedidor = v!),
          _buildTextField(label: 'Sexo', initialValue: _formData.dadosPessoais.sexo, onSaved: (v) => _formData.dadosPessoais.sexo = v!),
          _buildTextField(label: 'Estado Civil', initialValue: _formData.dadosPessoais.estadoCivil, onSaved: (v) => _formData.dadosPessoais.estadoCivil = v!),
          _buildTextField(label: 'Escolaridade', initialValue: _formData.dadosPessoais.escolaridade, onSaved: (v) => _formData.dadosPessoais.escolaridade = v!),
          _buildTextField(label: 'Profissão', initialValue: _formData.dadosPessoais.profissao, onSaved: (v) => _formData.dadosPessoais.profissao = v!),
          _buildTextField(label: 'Local de Trabalho', initialValue: _formData.dadosPessoais.localDeTrabalho, onSaved: (v) => _formData.dadosPessoais.localDeTrabalho = v!),
          _buildTextField(label: 'Naturalidade', initialValue: _formData.dadosPessoais.naturalidade, onSaved: (v) => _formData.dadosPessoais.naturalidade = v!),
          _buildTextField(label: 'UF Naturalidade', initialValue: _formData.dadosPessoais.naturalidadeUF, onSaved: (v) => _formData.dadosPessoais.naturalidadeUF = v!),
        ]),
      ),
      isExpanded: _expansionPanelOpenState[1],
    );
  }

  ExpansionPanel _buildAtividadesPanel() {
    return ExpansionPanel(
      headerBuilder: (c, isOpen) => const ListTile(
          title: Text('Atividades',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Wrap(
            spacing: 8,
            children: _formData.atividades.map((a) => Chip(
              label: Text(a),
              onDeleted: () => setState(() => _formData.atividades.remove(a)),
            )).toList(),
          ),
          Row(children: [
            Expanded(child: TextField(controller: _atividadeController, decoration: const InputDecoration(hintText: 'Nova atividade...'))),
            IconButton(icon: const Icon(Icons.add), onPressed: _addAtividade),
          ]),
        ]),
      ),
      isExpanded: _expansionPanelOpenState[2],
    );
  }

  ExpansionPanel _buildContribuicoesPanel() {
    return ExpansionPanel(
      headerBuilder: (c, isOpen) => const ListTile(
          title: Text('Contribuições',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          ..._formData.contribuicao.entries.map((e) => CheckboxListTile(
            title: Text(e.key),
            value: e.value,
            onChanged: (val) => setState(() => _formData.contribuicao[e.key] = val!),
            controlAffinity: ListTileControlAffinity.leading,
          )),
          Row(children: [
            Expanded(child: TextField(controller: _anoContribuicaoController, decoration: const InputDecoration(hintText: 'Adicionar ano...'), keyboardType: TextInputType.number)),
            IconButton(icon: const Icon(Icons.add), onPressed: _addContribuicao),
          ]),
        ]),
      ),
      isExpanded: _expansionPanelOpenState[3],
    );
  }

  Widget _buildTextField(
      {required String label,
        required String initialValue,
        required Function(String?) onSaved,
        bool isNumeric = false,
        bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        validator: (v) => (isRequired && (v == null || v.isEmpty)) ? '$label é obrigatório' : null,
        onSaved: onSaved,
      ),
    );
  }

  Widget _buildSwitch(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}
