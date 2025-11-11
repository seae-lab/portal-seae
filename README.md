Portal Administrativo de Gestão da SEAE (Projetos)

Este repositório contém o código-fonte do "Portal Administrativo de Gestão da SEAE", uma aplicação interna desenvolvida em Flutter e destinada a centralizar e gerenciar as operações administrativas da instituição.

A aplicação é primariamente um Portal Web (PWA) que se conecta diretamente aos serviços do Firebase (Autenticação, Firestore, Storage) para todas as suas operações de backend.

🔮 Visão Geral da Arquitetura

O projeto é estruturado em torno de três pilares principais: Firebase como Backend-as-a-Service (BaaS), flutter_modular para arquitetura de rotas e injeção de dependência, e provider para gerenciamento de estado reativo.

1. Tecnologias Principais

Framework: Flutter (SDK '>=3.9.0 <4.0.0')

Backend (BaaS): Firebase

Autenticação: firebase_auth (incluindo google_sign_in)

Banco de Dados: cloud_firestore (Banco NoSQL)

Armazenamento de Arquivos: firebase_storage

Hospedagem: firebase_hosting (configurado para Web)

Arquitetura de Módulos: flutter_modular

Usado para Injeção de Dependência (Binds) e Roteamento (Routes).

Gerenciamento de Estado: provider

Recursos Adicionais:

Gráficos: fl_chart

Geração de Relatórios: pdf e printing

Calendário: syncfusion_flutter_calendar

Upload de Arquivos: image_picker e file_picker

2. Modularização e Injeção de Dependência (app_module.dart)

O coração da arquitetura da aplicação é o lib/app_module.dart. Ele define todos os serviços (Binds) e rotas (Routes) da aplicação.

Serviços Injetados (Binds):

Os seguintes serviços são injetados como Singleton e estão disponíveis em toda a aplicação:

AuthService: Gerencia toda a lógica de autenticação, estado do usuário e permissões.

CadastroService: (Definido em secretaria_service.dart) Provê a lógica de negócios para os módulos da Secretaria (gestão de membros, relatórios, etc.).

DijService: Provê a lógica de negócios específica para o módulo DIJ (gestão de jovens, chamada, calendário).

3. Autorização e Controle de Acesso (Role-Based)

O controle de acesso é um pilar central desta aplicação e é implementado através de Guards do flutter_modular.

AuthGuard: Protege a rota principal /home. Se o usuário não estiver autenticado, ele é redirecionado para /login.

RoleGuard: Uma guarda customizada que protege todas as rotas internas (/dashboard, /gestao_membros, etc.). Ela verifica se o usuário autenticado possui o perfil (role) necessário para acessar aquela funcionalidade.

Perfis de Usuário (Roles) Identificados:

O RoleGuard revela uma estrutura de permissões granular. Os perfis (roles) são:

Administração:

admin: Acesso de superusuário (ex: acesso total e à rota /gestao_bases).

Secretaria:

secretaria: Perfil genérico da secretaria.

secretaria_dashboard: Acesso específico ao dashboard.

secretaria_membros: Acesso específico à gestão de membros.

secretaria_relatorios: Acesso específico aos relatórios.

DIJ (Departamento de Infância e Juventude):

dij: Perfil genérico do DIJ.

dij_diretora: Perfil de liderança do DIJ.

dij_ciclo_1

dij_ciclo_2

dij_ciclo_3

dij_grupo_pais

dij_pos_juventude

🚀 Estrutura de Módulos e Rotas

A aplicação é dividida nas seguintes seções principais, conforme definido em app_module.dart:

/: SplashScreen (Tela de carregamento inicial)

/login: LoginScreen (Tela de autenticação)

/home: HomeScreen (O layout principal que abriga todos os módulos abaixo)

Módulo Secretaria

/dashboard: Dashboard principal.

/gestao_membros: Gestão (CRUD) de membros.

/relatorios_membros: Hub de Relatórios da Secretaria.

/consulta_avancada: Relatório de consulta avançada.

/controle_contribuicoes: Relatório de contribuições.

/socios_elegiveis: Relatório de sócios elegíveis.

/socios_promoviveis: Relatório de sócios promovíveis.

/socios_votantes: Relatório de sócios votantes.

/colaboradores_departamento: Relatório de colaboradores por departamento.

/proposta_social: Relatório de proposta social.

/termo_adesao: Relatório de termo de adesão.

Módulo DIJ (Departamento de Infância e Juventude)

/dij: Página principal do módulo.

/dij/jovens: Gestão (CRUD) de jovens.

/dij/chamada: Funcionalidade de registro de presença/frequência.

/dij/calendario: Gestão de eventos e encontros do DIJ.

Módulo de Administração

/gestao_bases: (Acesso restrito a admin) Gestão de dados mestres da aplicação (ex: departamentos, tipos de sócio, etc.).

🖥️ Configuração Web e Deploy

O alvo principal deste projeto é a Web, e ele possui configurações específicas para otimizar essa plataforma.

1. Persistência de Sessão (Web)

O main.dart define uma política de persistência de autenticação específica para a web:

// lib/main.dart

if (const bool.fromEnvironment("dart.library.html")) {
await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
}


Importância: Isso significa que o login do usuário na web expira quando a sessão do navegador termina (ex: ao fechar a aba ou o navegador). O login não é mantido indefinidamente (o que aconteceria se fosse Persistence.LOCAL).

2. Service Worker (PWA)

O projeto está configurado para registrar um Service Worker (lib/src/sw_registrar_web.dart), tornando-o um Progressive Web App (PWA). Isso melhora o cache e o desempenho em acessos subsequentes.

3. Deploy (Firebase Hosting)

O arquivo firebase.json define as regras de deploy para o Firebase Hosting.

Diretório Público: O deploy é feito a partir da pasta build/web.

Configuração de SPA (Single Page Application):

"rewrites": [
{
"source": "**",
"destination": "/index.html"
}
]


Esta é a configuração vital para um app Flutter Web. Ela garante que todas as requisições de URL (ex: /home/dashboard) sejam direcionadas para o index.html, permitindo que o flutter_modular gerencie a rota no lado do cliente.

Estratégia de Cache:

O index.html é servido com no-cache, garantindo que os usuários sempre recebam a versão mais recente da aplicação.

Arquivos de assets e static são servidos com cache immutable de longa duração, para máxima performance.

🏁 Ambiente de Desenvolvimento (Como Rodar)

Para rodar este projeto localmente, siga os passos:

Clone o Repositório

git clone [URL_DO_REPOSITORIO]
cd portal-seae


Verifique a Versão do Flutter
Garanta que você está usando uma versão do SDK do Flutter compatível:

# Exemplo: fvm use 3.19.0 (ou uma versão >=3.9.0 <4.0.0)


Instale as Dependências

flutter pub get


Configuração do Firebase
O arquivo lib/firebase_options.dart já está no repositório e aponta para o projeto portal-seae.

Importante: Você não precisa rodar flutterfire configure. No entanto, para que a aplicação funcione, você precisa ter sua Conta Google (Gmail) autorizada como usuária no painel do Firebase Authentication do projeto portal-seae.

Além disso, seu usuário precisa ter as permissões (roles) corretas definidas (provavelmente via custom claims no Auth ou em um documento no Firestore) para poder acessar as rotas protegidas pelo RoleGuard.

Rode o Projeto (Web)

flutter run -d chrome


Rode o Projeto (Outras Plataformas)
O projeto também está configurado para Android, iOS, Windows e macOS (veja firebase_options.dart).

flutter run -d [windows | macos | android | ios]


<details>
<summary>📦 Dependências Principais (pubspec.yaml)</summary>

dependencies:
flutter:
sdk: flutter

# Pacotes principais do app
firebase_core: ^3.15.2
firebase_auth: ^5.7.0
cloud_firestore: ^5.6.12
provider: ^6.1.5
google_fonts: ^6.2.1
cupertino_icons: ^1.0.8
google_sign_in: ^6.2.1
font_awesome_flutter: ^10.9.0
flutter_svg: ^2.0.10
flutter_modular: ^6.4.1
firebase_storage: ^12.1.0
image_picker: ^1.1.2
http: ^1.2.1
mask_text_input_formatter: ^2.9.0
fl_chart: ^0.68.0
pdf: ^3.10.8
printing: ^5.14.2
file_picker: ^10.3.1
url_launcher: ^6.3.0
intl: ^0.20.2
syncfusion_flutter_calendar: ^29.2.5

flutter_localizations:
sdk: flutter
syncfusion_localizations: ^29.2.11
google_maps_flutter: ^2.12.3
flutter_map: ^8.2.1
latlong2: ^0.9.1


</details>