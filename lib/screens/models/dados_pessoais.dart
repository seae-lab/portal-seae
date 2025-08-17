class DadosPessoais {
  String sexo;
  String bairro;
  String celular;
  String cep;
  String cidade;
  String cpf;
  String dataNascimento;
  String email;
  String endereco;
  String escolaridade;
  String estadoCivil;
  String localDeTrabalho;
  String naturalidade;
  String naturalidadeUF;
  String profissao;
  String rg;
  String rgOrgaoExpedidor;
  String telComercial;
  String telResidencia;

  DadosPessoais({
    this.sexo = '',
    this.bairro = '',
    this.celular = '',
    this.cep = '',
    this.cidade = '',
    this.cpf = '',
    this.dataNascimento = '',
    this.email = '',
    this.endereco = '',
    this.escolaridade = '',
    this.estadoCivil = '',
    this.localDeTrabalho = '',
    this.naturalidade = '',
    this.naturalidadeUF = '',
    this.profissao = '',
    this.rg = '',
    this.rgOrgaoExpedidor = '',
    this.telComercial = '',
    this.telResidencia = '',
  });

  factory DadosPessoais.fromMap(Map<String, dynamic> data) {
    return DadosPessoais(
      sexo: data['Sexo'] ?? '',
      bairro: data['bairro'] ?? '',
      celular: data['celular'] ?? '',
      cep: data['cep'] ?? '',
      cidade: data['cidade'] ?? '',
      cpf: data['cpf'] ?? '',
      dataNascimento: data['data_nascimento'] ?? '',
      email: data['e-mail'] ?? '',
      endereco: data['endereco'] ?? '',
      escolaridade: data['escolaridade'] ?? '',
      estadoCivil: data['estado_civil'] ?? '',
      localDeTrabalho: data['local_de_trabalho'] ?? '',
      naturalidade: data['naturalidade'] ?? '',
      naturalidadeUF: data['naturalidade_uf'] ?? '',
      profissao: data['profissao'] ?? '',
      rg: data['rg'] ?? '',
      rgOrgaoExpedidor: data['rg_orgao_expedidor'] ?? '',
      telComercial: data['tel_comercial'] ?? '',
      telResidencia: data['tel_residencia'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Sexo': sexo,
      'bairro': bairro,
      'celular': celular,
      'cep': cep,
      'cidade': cidade,
      'cpf': cpf,
      'data_nascimento': dataNascimento,
      'e-mail': email,
      'endereco': endereco,
      'escolaridade': escolaridade,
      'estado_civil': estadoCivil,
      'local_de_trabalho': localDeTrabalho,
      'naturalidade': naturalidade,
      'naturalidade_uf': naturalidadeUF,
      'profissao': profissao,
      'rg': rg,
      'rg_orgao_expedidor': rgOrgaoExpedidor,
      'tel_comercial': telComercial,
      'tel_residencia': telResidencia,
    };
  }
}