import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AuthGuard extends RouteGuard {
  // Se a guarda falhar (usuário não logado tentando acessar rota protegida),
  // redireciona para a tela de login.
  AuthGuard() : super(redirectTo: '/');

  @override
  Future<bool> canActivate(String path, ModularRoute router) async {
    // A linha "isModuleReady" foi removida.
    // Agora, esperamos o Firebase verificar o estado de autenticação inicial.
    final user = await FirebaseAuth.instance.authStateChanges().first;

    // Verificamos se a rota que o usuário está tentando acessar é protegida.
    final isProtectedRoute = path.startsWith('/home');

    if (isProtectedRoute) {
      // Se a rota é protegida, só pode ser ativada se o usuário existir (não for nulo).
      return user != null;
    }

    // Se a rota NÃO é protegida (como a de login '/'),
    // verificamos se o usuário já está logado.
    if (user != null) {
      // Se já está logado, não deixamos ele ver a tela de login de novo.
      // Redirecionamos para a home e bloqueamos a rota de login atual.
      Modular.to.navigate('/home/overview');
      return false;
    }

    // Se não está logado, ele pode ver a tela de login.
    return true;
  }
}
