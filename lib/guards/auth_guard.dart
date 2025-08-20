import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/auth_service.dart';

class AuthGuard extends RouteGuard {
  AuthGuard() : super();

  @override
  Future<bool> canActivate(String path, ModularRoute route) async {
    final authService = Modular.get<AuthService>();
    final isAuthenticated = authService.isAuthenticated;

    if (!isAuthenticated && path != '/') {
      Modular.to.navigate('/');
      return false;
    } else if (isAuthenticated) {
      // Se o usuário está autenticado, permite o acesso.
      return true;
    }

    // Se o usuário não está autenticado e está tentando acessar a rota de login ('/'), permite.
    return true;
  }
}