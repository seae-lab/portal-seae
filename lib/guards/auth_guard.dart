import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AuthGuard extends RouteGuard {
  // Se a guarda falhar (usuário não logado tentando acessar rota protegida),
  // redireciona para a tela de login.
  AuthGuard() : super(redirectTo: '/');

  @override
  Future<bool> canActivate(String path, ModularRoute router) async {
    // Esperamos o Firebase verificar o estado de autenticação inicial.
    final user = await FirebaseAuth.instance.authStateChanges().first;

    // Verificamos se a rota que o usuário está tentando acessar é a de login.
    final isTryingToLogin = path == '/';

    if (isTryingToLogin) {
      // Se está tentando acessar a tela de login:
      if (user != null) {
        // Se já está logado, não deixamos ele ver a tela de login de novo.
        // Redirecionamos para a home e bloqueamos a rota de login atual.
        Modular.to.navigate('/home/overview');
        return false;
      }
      // Se não está logado, ele PODE ver a tela de login.
      return true;
    }

    // Se está tentando acessar qualquer outra rota (protegida):
    if (user == null) {
      // Se não está logado, manda para o login e bloqueia a rota atual.
      Modular.to.navigate('/');
      return false;
    }

    // Se está logado, pode acessar a rota protegida.
    return true;
  }
}
