// lib/app_module.dart

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/screens/auth/login_screen.dart';
import 'package:projetos/screens/dij/dij_page.dart';
import 'package:projetos/screens/home_screen.dart';
import 'package:projetos/screens/secretaria/dashboard_page.dart';
import 'package:projetos/screens/secretaria/gestao_membros_page.dart';
import 'package:projetos/screens/secretaria/relatorios/colaboradores_departamento_page.dart';
import 'package:projetos/screens/secretaria/relatorios/controle_contribuicoes_page.dart';
import 'package:projetos/screens/secretaria/relatorios/socios_promoviveis_page.dart';
import 'package:projetos/screens/secretaria/relatorios_membros_page.dart';
import 'package:projetos/screens/secretaria/relatorios/consulta_avancada_page.dart';
import 'package:projetos/screens/secretaria/relatorios/socios_elegiveis_page.dart';
import 'package:projetos/screens/secretaria/relatorios/socios_votantes_page.dart';
import 'package:projetos/services/auth_service.dart';
import 'package:projetos/services/cadastro_service.dart';
import 'guards/auth_guard.dart';
import 'guards/role_guard.dart';

class AppModule extends Module {
  @override
  void binds(i) {
    i.addSingleton(AuthService.new);
    i.addSingleton(CadastroService.new);
    i.addSingleton<RouteObserver<Route<dynamic>>>(RouteObserver<Route<dynamic>>.new);
  }

  @override
  void routes(r) {
    r.child('/', child: (context) => const LoginScreen(), guards: [AuthGuard()]);

    r.child('/home',
        child: (context) => const HomeScreen(),
        guards: [AuthGuard()],
        children: [
          ChildRoute('/dashboard',
              child: (context) => const DashboardPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria', 'secretaria_dashboard'])]),
          ChildRoute('/gestao_membros',
              child: (context) => const GestaoMembrosPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria_membros'])]),
          ChildRoute('/relatorios_membros',
              child: (context) => const RelatoriosMembrosPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria_relatorios'])]),
          ChildRoute('/consulta_avancada',
              child: (context) => const ConsultaAvancadaPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria_relatorios'])]),
          ChildRoute('/controle_contribuicoes',
              child: (context) => const ControleContribuicoesPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria_relatorios'])]),

          ChildRoute('/socios_elegiveis',
              child: (context) => const SociosElegiveisPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria_relatorios'])]),
          ChildRoute('/socios_promoviveis',
              child: (context) => const SociosPromoviveisPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria_relatorios'])]),
          ChildRoute('/socios_votantes',
              child: (context) => const SociosVotantesPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria_relatorios'])]),
          ChildRoute('/colaboradores_departamento',
              child: (context) => const ColaboradoresDepartamentoPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria_relatorios'])]),

          ChildRoute('/dij',
              child: (context) => const DijPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'dij'])])
        ]);
  }
}