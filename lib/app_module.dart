import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/screens/home/home_screen.dart';
import 'package:projetos/screens/home/pages/dij_page.dart';
import 'package:projetos/screens/home/pages/overview_page.dart';
import 'package:projetos/screens/home/pages/users_page.dart'; // Crie este arquivo
import 'package:projetos/screens/login_screen.dart';
import 'package:projetos/services/auth_service.dart';
import 'guards/auth_guard.dart';
import 'guards/role_guard.dart';

// ... (imports)

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
          // NOMES DOS PAPÉIS ATUALIZADOS NO GUARD
          ChildRoute('/overview', child: (context) => const OverviewPage(), guards: [
            RoleGuard(allowedRoles: ['admin'])
          ]),

          ChildRoute('/users', child: (context) => const UsersPage(), guards: [
            RoleGuard(allowedRoles: ['admin'])
          ]),

          ChildRoute('/dij', child: (context) => const DijPage(), guards: [
            // Agora 'admin' ou 'dij' podem acessar
            RoleGuard(allowedRoles: ['admin', 'dij'])
          ]),
        ]);
  }
}