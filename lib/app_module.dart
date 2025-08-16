import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/screens/home/home_screen.dart';
import 'package:projetos/screens/home/pages/dij_page.dart'; // Crie este arquivo
import 'package:projetos/screens/home/pages/overview_page.dart';
import 'package:projetos/screens/home/pages/users_page.dart'; // Crie este arquivo
import 'package:projetos/screens/login_screen.dart';
import 'package:projetos/services/auth_service.dart';
import 'guards/auth_guard.dart';
import 'guards/role_guard.dart';

class AppModule extends Module {
  @override
  void binds(i) {
    i.addSingleton(AuthService.new);
  }

  @override
  void routes(r) {
    r.child('/', child: (context) => const LoginScreen(), guards: [AuthGuard()]);

    r.child('/home',
        child: (context) => const HomeScreen(),
        guards: [AuthGuard()],
        children: [
          // Apenas admins podem ver a Visão Geral
          ChildRoute('/overview', child: (context) => const OverviewPage(), guards: [
            RoleGuard(allowedRoles: ['papel_admin'])
          ]),

          // Apenas admins podem ver a página de Usuários
          ChildRoute('/users', child: (context) => const UsersPage(), guards: [
            RoleGuard(allowedRoles: ['papel_admin'])
          ]),

          // Usuários com papel_admin OU papel_dij podem ver esta página
          ChildRoute('/dij', child: (context) => const DijPage(), guards: [
            RoleGuard(allowedRoles: ['papel_admin', 'papel_dij'])
          ]),
        ]);
  }
}