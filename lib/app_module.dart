// Conteúdo atualizado de ferrazt/pag-seae/pag-seae-f1ecfa12a567d6280aa4dbc6787d965af79b4a34/lib/app_module.dart
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/screens/auth/login_screen.dart';
import 'package:projetos/screens/dij/calendario_encontros_page.dart';
import 'package:projetos/screens/dij/dij_page.dart';
import 'package:projetos/screens/home_screen.dart';
import 'package:projetos/screens/secretaria/dashboard_page.dart';
import 'package:projetos/screens/secretaria/gestao_membros_page.dart';
import 'package:projetos/screens/secretaria/relatorios/colaboradores_departamento_page.dart';
import 'package:projetos/screens/secretaria/relatorios/controle_contribuicoes_page.dart';
import 'package:projetos/screens/secretaria/relatorios/proposta_social_page.dart';
import 'package:projetos/screens/secretaria/relatorios/socios_promoviveis_page.dart';
import 'package:projetos/screens/secretaria/relatorios/termo_adesao_page.dart';
import 'package:projetos/screens/secretaria/relatorios_membros_page.dart';
import 'package:projetos/screens/secretaria/relatorios/consulta_avancada_page.dart';
import 'package:projetos/screens/secretaria/relatorios/socios_elegiveis_page.dart';
import 'package:projetos/screens/secretaria/relatorios/socios_votantes_page.dart';
import 'package:projetos/screens/splash_screen.dart';
import 'package:projetos/services/auth_service.dart';
// ATUALIZADO: Import do novo nome de arquivo
import 'package:projetos/services/secretaria_service.dart';
import 'guards/auth_guard.dart';
import 'guards/role_guard.dart';
import 'package:projetos/screens/secretaria/gestao_bases_page.dart';
import 'package:projetos/screens/dij/gestao_jovens_dij_page.dart';
import 'package:projetos/screens/dij/chamada_dij_page.dart';
import 'package:projetos/services/dij_service.dart';


class AppModule extends Module {
  @override
  void binds(i) {
    i.addSingleton(AuthService.new);
    i.addSingleton(CadastroService.new);
    i.addSingleton(DijService.new);
  }

  @override
  void routes(r) {
    r.child('/', child: (context) => const SplashScreen());
    r.child('/login', child: (context) => const LoginScreen());

    r.child('/home',
        child: (context) => const HomeScreen(),
        guards: [AuthGuard()],
        children: [
          ChildRoute('/dashboard',
              child: (context) => const DashboardPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria', 'secretaria_dashboard'])]),
          ChildRoute('/gestao_membros',
              child: (context) => const GestaoMembrosPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria', 'secretaria_membros'])]),
          ChildRoute('/relatorios_membros',
              child: (context) => const RelatoriosMembrosPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria', 'secretaria_relatorios'])]),
          ChildRoute('/consulta_avancada',
              child: (context) => const ConsultaAvancadaPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria', 'secretaria_relatorios'])]),
          ChildRoute('/controle_contribuicoes',
              child: (context) => const ControleContribuicoesPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria', 'secretaria_relatorios'])]),
          ChildRoute('/socios_elegiveis',
              child: (context) => const SociosElegiveisPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria', 'secretaria_relatorios'])]),
          ChildRoute('/socios_promoviveis',
              child: (context) => const SociosPromoviveisPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria', 'secretaria_relatorios'])]),
          ChildRoute('/socios_votantes',
              child: (context) => const SociosVotantesPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria', 'secretaria_relatorios'])]),
          ChildRoute('/colaboradores_departamento',
              child: (context) => const ColaboradoresDepartamentoPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria', 'secretaria_relatorios'])]),
          ChildRoute('/proposta_social',
              child: (context) => const PropostaSocialPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria', 'secretaria_relatorios'])]),
          ChildRoute('/termo_adesao',
              child: (context) => const TermoAdesaoPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria', 'secretaria_relatorios'])]),
          ChildRoute('/gestao_bases',
              child: (context) => const GestaoBasesPage(),
              guards: [RoleGuard(allowedRoles: ['admin'])]),

          // ---- ROTAS DO DIJ ATUALIZADAS ----
          ChildRoute('/dij',
              child: (context) => const DijPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'dij', 'dij_diretora', 'dij_ciclo_1', 'dij_ciclo_2', 'dij_ciclo_3', 'dij_pos_juventude'])]),
          ChildRoute('/dij/jovens',
              child: (context) => const GestaoJovensDijPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'dij', 'dij_diretora', 'dij_ciclo_1', 'dij_ciclo_2', 'dij_ciclo_3', 'dij_pos_juventude'])]),
          ChildRoute('/dij/chamada',
              child: (context) => const ChamadaDijPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'dij', 'dij_diretora', 'dij_ciclo_1', 'dij_ciclo_2', 'dij_ciclo_3', 'dij_pos_juventude'])]),
          ChildRoute('/dij/calendario',
              child: (context) => const CalendarioEncontrosPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'dij', 'dij_diretora', 'dij_ciclo_1', 'dij_ciclo_2', 'dij_ciclo_3', 'dij_pos_juventude'])]),
        ]);
  }
}