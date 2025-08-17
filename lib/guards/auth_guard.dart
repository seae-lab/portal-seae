import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/auth_service.dart';

class AuthGuard extends RouteGuard {
  AuthGuard() : super(redirectTo: '/');

  @override
  Future<bool> canActivate(String path, ModularRoute route) async {
    final user = FirebaseAuth.instance.currentUser;

    // --- CENÁRIO 1: Usuário NÃO está logado no Firebase ---
    if (user == null) {
      // Permite o acesso apenas à tela de login ('/').
      // Se tentar acessar qualquer outra página, será redirecionado para '/'.
      return path == '/';
    }

    // --- CENÁRIO 2: Usuário ESTÁ logado no Firebase (Sessão persistiu após refresh) ---
    final authService = Modular.get<AuthService>();

    // Tenta carregar as permissões do usuário a partir do Firestore.
    // Isso "reidrata" o estado do app.
    final bool hasPermissions =
    await authService.tryToLoadPermissionsForCurrentUser();

    if (!hasPermissions) {
      // Se o usuário está logado no Firebase mas não tem permissões no Firestore,
      // o acesso a rotas protegidas é negado. Ele é forçado a deslogar e voltar para '/'.
      return path == '/';
    }

    // --- CENÁRIO 3: Usuário está logado E com permissões carregadas ---

    // Se ele está totalmente autenticado e tenta acessar a tela de login...
    if (path == '/') {
      // ...redirecionamos para a sua página inicial designada, evitando que veja o login de novo.
      final initialRoute = authService.getInitialRouteForUser();
      Modular.to.navigate(initialRoute);
      return false; // Impede a navegação para '/'
    }

    // Se a rota for qualquer outra (protegida), o acesso é permitido.
    return true;
  }
}