// lib/guards/login_guard.dart

import 'dart:async';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/auth_service.dart';

/// Este Guard impede que um usuário já logado acesse a tela de login novamente.
class LoginGuard extends RouteGuard {
  LoginGuard() : super(redirectTo: '/home/dashboard');

  @override
  Future<bool> canActivate(String path, ModularRoute route) async {
    final authService = Modular.get<AuthService>();

    // Se o usuário NÃO está logado (não tem permissões carregadas), ele PODE acessar a tela de login.
    if (authService.currentUserPermissions == null) {
      return true;
    }

    // Se o usuário JÁ ESTÁ logado, ele NÃO PODE acessar a tela de login e será redirecionado.
    return false;
  }
}