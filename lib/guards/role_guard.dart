import 'package:flutter_modular/flutter_modular.dart';
import '../services/auth_service.dart';

// O Guard agora aceita uma lista de papéis que podem acessar a rota
class RoleGuard extends RouteGuard {
  final List<String> allowedRoles;

  RoleGuard({required this.allowedRoles}) : super(redirectTo: '/');

  @override
  Future<bool> canActivate(String path, ModularRoute route) async {
    final authService = Modular.get<AuthService>();

    if (authService.currentUserPermissions == null) {
      return false; // Não está logado ou não tem permissões carregadas
    }

    // Se for admin, o acesso é sempre permitido.
    if (authService.currentUserPermissions!.isAdmin) {
      return true;
    }

    // Verifica se o usuário tem PELO MENOS UM dos papéis permitidos.
    for (final role in allowedRoles) {
      if (authService.currentUserPermissions!.hasRole(role)) {
        return true; // Encontrou um papel correspondente, permite o acesso.
      }
    }

    return false; // Não tem nenhum dos papéis necessários, bloqueia.
  }
}