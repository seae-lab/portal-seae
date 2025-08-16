import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/auth_service.dart';

class SideMenuWidget extends StatelessWidget {
  const SideMenuWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Modular.get<AuthService>();
    final permissions = authService.currentUserPermissions;
    final currentRoute = Modular.routerDelegate.path;

    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            child: Image.asset('assets/images/logo_SEAE_azul.png'),
          ),

          // ---- WIDGETS CONDICIONAIS ----
          // O 'if' dentro da lista só adiciona o widget se a condição for verdadeira

          if (permissions?.hasRole('papel_admin') ?? false)
            ListTile(
              onTap: () => Modular.to.navigate('/home/overview'),
              selected: currentRoute.startsWith('/home/overview'),
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Visão Geral'),
            ),

          if (permissions?.hasRole('papel_admin') ?? false)
            ListTile(
              onTap: () => Modular.to.navigate('/home/users'),
              selected: currentRoute.startsWith('/home/users'),
              leading: const Icon(Icons.people_alt_outlined),
              title: const Text('Usuários'),
            ),

          if (permissions?.hasRole('papel_dij') ?? false)
            ListTile(
              onTap: () => Modular.to.navigate('/home/dij'),
              selected: currentRoute.startsWith('/home/dij'),
              leading: const Icon(Icons.book_outlined), // Exemplo de ícone
              title: const Text('Página DIJ'),
            ),

          const Divider(),
          ListTile(
            onTap: () async {
              await authService.signOut();
              Modular.to.navigate('/');
            },
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}