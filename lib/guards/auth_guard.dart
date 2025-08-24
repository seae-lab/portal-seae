import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/auth_service.dart';

class AuthGuard extends RouteGuard {
  AuthGuard() : super(redirectTo: '/login');

  @override
  Future<bool> canActivate(String path, ModularRoute route) async {
    final authService = Modular.get<AuthService>();
    // AGUARDA a verificação de auth ser concluída antes de prosseguir
    await authService.initialAuthCheck;

    if (authService.isAuthenticated) {
      return true; // Permite o acesso se autenticado
    }

    return false; // Bloqueia e redireciona para /login se não autenticado
  }
}