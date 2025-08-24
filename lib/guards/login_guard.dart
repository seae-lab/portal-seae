import 'dart:async';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/auth_service.dart';

/// Este Guard impede que um usuário já logado acesse a tela de login novamente.
class LoginGuard extends RouteGuard {
  LoginGuard() : super(redirectTo: '/home/dashboard');

  @override
  Future<bool> canActivate(String path, ModularRoute route) async {
    final authService = Modular.get<AuthService>();

    // AGUARDA a verificação de auth ser concluída
    await authService.initialAuthCheck;

    // Se o usuário NÃO está logado, ele PODE acessar a tela de login.
    if (!authService.isAuthenticated) {
      return true;
    }

    // Se o usuário JÁ ESTÁ logado, ele NÃO PODE acessar a tela de login e será redirecionado.
    return false;
  }
}