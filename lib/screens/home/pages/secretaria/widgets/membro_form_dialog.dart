import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:projetos/screens/models/dados_pessoais.dart';
import 'package:projetos/screens/models/membro.dart';
import 'package:projetos/services/cadastro_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  final List<bool> _expansionPanelOpenState = [true, true];
  List<String> _allDepartamentos = [];
  Map<String, String> _allSituacoes = {};
  List<String> _allAnosContribuicao = [];
  List<String> _allTiposMediunidade = [];
  final List<String> _sexoOptions = ['Masculino', 'Feminino', 'Não especificado'];
  final List<String> _escolaridadeOptions = [
    'Ensino Fundamental - Incompleto',
    'Ensino Fundamental - Completo',
    'Ensino Médio - Incompleto',
    'Ensino Médio - Completo',
    'Magistério - Completo',
    'Ensino Superior - Incompleto',
    'Ensino Superior - Completo',
    'Mestrado - Incompleto',
    'Mestrado - Completo',
    'Doutorado - Incompleto',
    'Doutorado - Completo'
  ];
  final List<String> _estadosCivis = ['Solteiro (a)', 'Casado (a)', 'Divorciado (a)', 'Viúvo (a)', 'Separado (a)'];
  bool _isLoadingBases = true;
  final _cepController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _ufController = TextEditingController();
  final _cepMask = MaskTextInputFormatter(mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});
  final _celularMask = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _telefoneMask = MaskTextInputFormatter(mask: '(##) ####-####', filter: {"#": RegExp(r'[0-9]')});
  final _cpfMask = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  final _dataMask = MaskTextInputFormatter(mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    _isNewMember = widget.membro == null;
    _loadBases();

    if (widget.membro != null) {
      final m = widget.membro!;
      _formData = Membro(
        id: m.id,
        nome: m.nome,
        foto: m.foto,
        atividades: List<String>.from(m.atividades),
        contribuicao: Map<String, bool>.from(m.contribuicao),
        dadosPessoais: DadosPessoais.fromMap(m.dadosPessoais.toMap()),
        atualizacao: m.atualizacao,
        atualizacaoCD: m.atualizacaoCD,
        atualizacaoCF: m.atualizacaoCF,
        dataAprovacaoCD: m.dataAprovacaoCD,
        dataAtualizacao: m.dataAtualizacao,
        dataProposta: m.dataProposta,
        frequentaSeaeDesde: m.frequentaSeaeDesde,
        frequentouOutrosCentros: m.frequentouOutrosCentros,
        listaContribuintes: m.listaContribuintes,
        mediunidadeOstensiva: m.mediunidadeOstensiva,
        novoSocio: m.novoSocio,
        situacaoSEAE: m.situacaoSEAE,
        tiposMediunidade: List<String>.from(m.tiposMediunidade),
        transfAutomatica: m.transfAutomatica,
      );
      _cepController.text = _formData.dadosPessoais.cep;
      _enderecoController.text = _formData.dadosPessoais.endereco;
      _bairroController.text = _formData.dadosPessoais.bairro;
      _cidadeController.text = _formData.dadosPessoais.cidade;
      _ufController.text = _formData.dadosPessoais.naturalidadeUF;
    } else {
      _formData = Membro(
        nome: '',
        dadosPessoais: DadosPessoais(),
      );
    }

    _cepController.addListener(_onCepChanged);
  }

  @override
  void dispose() {
    _cepController.removeListener(_onCepChanged);
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
    if (address.isNotEmpty && mounted) {
      setState(() {
        _enderecoController.text = address['endereco']!;
        _bairroController.text = address['bairro']!;
        _cidadeController.text = address['cidade']!;
        _ufController.text = address['uf']!;
      });
    }
  }

  Future<void> _loadBases() async {
    try {
      final deptsFuture = _cadastroService.getDepartamentos();
      final situacoesFuture = _cadastroService.getSituacoes();
      final anosFuture = _cadastroService.getAnosContribuicao();
      final mediunidadesFuture = _cadastroService.getTiposMediunidade();

      final results = await Future.wait([deptsFuture, situacoesFuture, anosFuture, mediunidadesFuture]);

      if (mounted) {
        setState(() {
          _allDepartamentos = results[0] as List<String>;
          _allSituacoes = results[1] as Map<String, String>;
          _allAnosContribuicao = results[2] as List<String>;
          _allTiposMediunidade = results[3] as List<String>;
          _isLoadingBases = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBases = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar bases de dados: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() => _newImageBytes = bytes);
    }
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isSaving = true);

      try {
        if (_isNewMember) {
          // CORRIGIDO: Usa a collection pública
          final DocumentReference docRef = await _cadastroService.membrosCollection.add(_formData.toFirestore());
          _formData.id = docRef.id;
        }

        if (_newImageBytes != null) {
          _formData.foto = await _cadastroService.uploadProfileImage(
            memberId: _formData.id!,
            fileBytes: _newImageBytes!,
          );
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
        if (mounted) setState(() => _isSaving = false);
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
        child: _isLoadingBases
            ? const Center(child: CircularProgressIndicator())
            : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                  label: 'Nome Completo',
                  initialValue: _formData.nome,
                  onSaved: (v) => _formData.nome = v!,
                  isRequired: true),
              DropdownButtonFormField<String>(
                value: _formData.situacaoSEAE > 0 && _allSituacoes.containsKey(_formData.situacaoSEAE.toString())
                    ? _formData.situacaoSEAE.toString()
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Situação SEAE',
                  border: OutlineInputBorder(),
                ),
                items: _allSituacoes.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _formData.situacaoSEAE = int.tryParse(newValue ?? '0') ?? 0;
                  });
                },
                onSaved: (v) => _formData.situacaoSEAE = int.tryParse(v ?? '0') ?? 0,
              ),
              const SizedBox(height: 16),
              Text('Atividades / Departamentos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _allDepartamentos.map((deptoAbreviacao) {
                  final bool isSelected =
                  _formData.atividades.contains(deptoAbreviacao);
                  return FilterChip(
                    label: Text(deptoAbreviacao),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _formData.atividades.add(deptoAbreviacao);
                        } else {
                          _formData.atividades.remove(deptoAbreviacao);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const Divider(height: 24),
              _buildTextField(
                  label: 'Frequenta desde (ano)',
                  initialValue: _formData.frequentaSeaeDesde > 0
                      ? _formData.frequentaSeaeDesde.toString()
                      : '',
                  onSaved: (v) =>
                  _formData.frequentaSeaeDesde = int.tryParse(v!) ?? 0,
                  isNumeric: true),

              _buildMultiSelectMediunidadeField(),

              _buildTextField(
                  label: 'Data Proposta',
                  initialValue: _formData.dataProposta,
                  onSaved: (v) => _formData.dataProposta = v!,
                  mask: _dataMask),
              _buildTextField(
                  label: 'Data Aprovação CD',
                  initialValue: _formData.dataAprovacaoCD,
                  onSaved: (v) => _formData.dataAprovacaoCD = v!,
                  mask: _dataMask),
              _buildTextField(
                  label: 'Data Atualização',
                  initialValue: _formData.dataAtualizacao,
                  onSaved: (v) => _formData.dataAtualizacao = v!,
                  mask: _dataMask),
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

              const Divider(height: 24),

              Text('Contribuições', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _allAnosContribuicao.map((ano) {
                  final bool isPaid = _formData.contribuicao[ano] ?? false;
                  return ChoiceChip(
                    label: Text(ano),
                    selected: isPaid,
                    onSelected: (bool selected) {
                      setState(() {
                        _formData.contribuicao[ano] = selected;
                      });
                    },
                  );
                }).toList(),
              ),
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
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Informações Pessoais', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _buildTextField(label: 'Email', initialValue: _formData.dadosPessoais.email, onSaved: (v) => _formData.dadosPessoais.email = v!),
              _buildTextField(label: 'Celular', initialValue: _formData.dadosPessoais.celular, onSaved: (v) => _formData.dadosPessoais.celular = v!, mask: _celularMask, isNumeric: true),
              _buildTextField(label: 'Telefone Residencial', initialValue: _formData.dadosPessoais.telResidencia, onSaved: (v) => _formData.dadosPessoais.telResidencia = v!, mask: _telefoneMask, isNumeric: true),
              _buildTextField(label: 'Telefone Comercial', initialValue: _formData.dadosPessoais.telComercial, onSaved: (v) => _formData.dadosPessoais.telComercial = v!, mask: _telefoneMask, isNumeric: true),
              _buildTextField(label: 'Data de Nascimento', initialValue: _formData.dadosPessoais.dataNascimento, onSaved: (v) => _formData.dadosPessoais.dataNascimento = v!, mask: _dataMask, isNumeric: true),
              _buildTextField(label: 'CPF', initialValue: _formData.dadosPessoais.cpf, onSaved: (v) => _formData.dadosPessoais.cpf = v!, mask: _cpfMask, isNumeric: true),
              _buildTextField(label: 'RG', initialValue: _formData.dadosPessoais.rg, onSaved: (v) => _formData.dadosPessoais.rg = v!),
              _buildTextField(label: 'Orgão Exp. RG', initialValue: _formData.dadosPessoais.rgOrgaoExpedidor, onSaved: (v) => _formData.dadosPessoais.rgOrgaoExpedidor = v!),

              _buildDropdown(
                label: 'Sexo',
                value: _formData.dadosPessoais.sexo,
                items: _sexoOptions,
                onChanged: (val) => setState(() => _formData.dadosPessoais.sexo = val ?? ''),
                onSaved: (val) => _formData.dadosPessoais.sexo = val ?? '',
              ),

              _buildDropdown(
                label: 'Estado Civil',
                value: _formData.dadosPessoais.estadoCivil,
                items: _estadosCivis,
                onChanged: (val) => setState(() => _formData.dadosPessoais.estadoCivil = val ?? ''),
                onSaved: (val) => _formData.dadosPessoais.estadoCivil = val ?? '',
              ),

              _buildDropdown(
                label: 'Escolaridade',
                value: _formData.dadosPessoais.escolaridade,
                items: _escolaridadeOptions,
                onChanged: (val) => setState(() => _formData.dadosPessoais.escolaridade = val ?? ''),
                onSaved: (val) => _formData.dadosPessoais.escolaridade = val ?? '',
              ),

              _buildTextField(label: 'Profissão', initialValue: _formData.dadosPessoais.profissao, onSaved: (v) => _formData.dadosPessoais.profissao = v!),
              _buildTextField(label: 'Local de Trabalho', initialValue: _formData.dadosPessoais.localDeTrabalho, onSaved: (v) => _formData.dadosPessoais.localDeTrabalho = v!),
              _buildTextField(label: 'Naturalidade', initialValue: _formData.dadosPessoais.naturalidade, onSaved: (v) => _formData.dadosPessoais.naturalidade = v!),

              const Divider(height: 24),

              Text('Endereço', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _buildTextField(
                  label: 'CEP',
                  onSaved: (v) => _formData.dadosPessoais.cep = v!,
                  controller: _cepController,
                  mask: _cepMask,
                  isNumeric: true),
              _buildTextField(
                  label: 'Endereço',
                  onSaved: (v) => _formData.dadosPessoais.endereco = v!,
                  controller: _enderecoController),
              _buildTextField(
                  label: 'Complemento',
                  initialValue: _formData.dadosPessoais.complemento,
                  onSaved: (v) => _formData.dadosPessoais.complemento = v!),
              _buildTextField(
                  label: 'Bairro',
                  onSaved: (v) => _formData.dadosPessoais.bairro = v!,
                  controller: _bairroController),
              _buildTextField(
                  label: 'Cidade',
                  onSaved: (v) => _formData.dadosPessoais.cidade = v!,
                  controller: _cidadeController),
              _buildTextField(
                  label: 'UF',
                  onSaved: (v) => _formData.dadosPessoais.naturalidadeUF = v!,
                  controller: _ufController),
            ]),
      ),
      isExpanded: _expansionPanelOpenState[1],
    );
  }

  Widget _buildTextField({
    required String label,
    required Function(String?) onSaved,
    String? initialValue,
    TextEditingController? controller,
    MaskTextInputFormatter? mask,
    bool isNumeric = false,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        initialValue: controller == null ? initialValue : null,
        controller: controller,
        inputFormatters: mask != null ? [mask] : null,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        validator: (v) => (isRequired && (v == null || v.isEmpty)) ? '$label é obrigatório' : null,
        onSaved: onSaved,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    required void Function(String?) onSaved,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: value.isNotEmpty && items.contains(value) ? value : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
        onSaved: onSaved,
      ),
    );
  }

  Widget _buildMultiSelectMediunidadeField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: FormField<List<String>>(
        initialValue: _formData.tiposMediunidade,
        onSaved: (val) {
          _formData.tiposMediunidade = val ?? [];
        },
        builder: (field) {
          return InputDecorator(
            decoration: InputDecoration(
              labelText: 'Tipos de Mediunidade',
              border: const OutlineInputBorder(),
              errorText: field.errorText,
            ),
            child: InkWell(
              onTap: () async {
                final List<String>? result = await showDialog<List<String>>(
                  context: context,
                  builder: (BuildContext context) {
                    return MultiSelectDialog(
                      items: _allTiposMediunidade,
                      initialSelectedItems: _formData.tiposMediunidade,
                    );
                  },
                );
                if (result != null) {
                  setState(() {
                    _formData.tiposMediunidade = result;
                    field.didChange(result);
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: _formData.tiposMediunidade.isEmpty
                    ? const Text('Selecione os tipos', style: TextStyle(color: Colors.grey))
                    : Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: _formData.tiposMediunidade
                      .map((item) => Chip(label: Text(item)))
                      .toList(),
                ),
              ),
            ),
          );
        },
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

class MultiSelectDialog extends StatefulWidget {
  final List<String> items;
  final List<String> initialSelectedItems;

  const MultiSelectDialog({super.key, required this.items, required this.initialSelectedItems});

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
      title: const Text('Selecione os Tipos'),
      content: SingleChildScrollView(
        child: ListBody(
          children: widget.items.map((item) {
            return CheckboxListTile(
              value: _selectedItems.contains(item),
              title: Text(item),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (isChecked) {
                setState(() {
                  if (isChecked ?? false) {
                    _selectedItems.add(item);
                  } else {
                    _selectedItems.remove(item);
                  }
                });
              },
            );
          }).toList(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          child: const Text('Confirmar'),
          onPressed: () {
            Navigator.of(context).pop(_selectedItems);
          },
        ),
      ],
    );
  }
}