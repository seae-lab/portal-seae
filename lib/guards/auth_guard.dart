// lib/guards/auth_guard.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/auth_service.dart';

class AuthGuard extends RouteGuard {
  AuthGuard() : super(redirectTo: '/');

  @override
  Future<bool> canActivate(String path, ModularRoute route) async {
    // Aguarda um pequeno instante para o Firebase inicializar na web
    await Future.delayed(const Duration(milliseconds: 100));

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return path == '/';
    }

    final authService = Modular.get<AuthService>();
    final bool hasPermissions = await authService.tryToLoadPermissionsForCurrentUser();

    if (!hasPermissions) {
      // Força o logout se o usuário do Firebase não tem permissões no app
      await authService.signOut();
      return path == '/';
    }

    if (path == '/') {
      final initialRoute = authService.getInitialRouteForUser();
      Modular.to.pushNamedAndRemoveUntil(initialRoute, (_) => false);
      return false;
    }

    return true;
  }
}