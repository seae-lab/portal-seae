import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/screens/home/home_screen.dart';
import 'package:projetos/screens/home/pages/dij/dij_page.dart';
import 'package:projetos/screens/home/pages/secretaria/dashboard_page.dart';
import 'package:projetos/screens/home/pages/secretaria/gestao_membros_page.dart';
import 'package:projetos/screens/home/pages/secretaria/relatorios_membros_page.dart';
import 'package:projetos/screens/login_screen.dart';
import 'package:projetos/services/auth_service.dart';
import 'package:projetos/services/cadastro_service.dart';
import 'guards/auth_guard.dart';
import 'guards/role_guard.dart';

class AppModule extends Module {
  @override
  void binds(i) {
    i.addSingleton(AuthService.new);
    i.addSingleton(CadastroService.new);
  }

  @override
  void routes(r) {
    r.child('/', child: (context) => const LoginScreen(), guards: [AuthGuard()]);

    r.child('/home',
        child: (context) => const HomeScreen(),
        guards: [AuthGuard()],
        children: [
          // SECRETARIA
          ChildRoute('/dashboard',
              child: (context) => const DashboardPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria_dashboard'])]),

          // ROTA ATUALIZADA: Acesso permitido para admin e secretaria_membros (visualização).
          ChildRoute('/gestao_membros',
              child: (context) => const GestaoMembrosPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria_membros'])]),

          ChildRoute('/relatorios_membros',
              child: (context) => const RelatoriosMembrosPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'secretaria_relatorios'])]),

          // DIJ
          ChildRoute('/dij',
              child: (context) => const DijPage(),
              guards: [RoleGuard(allowedRoles: ['admin', 'dij'])]),
        ]);
  }
}