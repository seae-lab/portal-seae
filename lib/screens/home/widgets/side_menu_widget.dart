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

          // NOMES DOS PAPÉIS ATUALIZADOS
          if (permissions?.hasRole('admin') ?? false)
            ListTile(
              onTap: () => Modular.to.navigate('/home/overview'),
              selected: currentRoute.startsWith('/home/overview'),
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Visão Geral'),
            ),

          if (permissions?.hasRole('admin') ?? false)
            ListTile(
              onTap: () => Modular.to.navigate('/home/users'),
              selected: currentRoute.startsWith('/home/users'),
              leading: const Icon(Icons.people_alt_outlined),
              title: const Text('Usuários'),
            ),

          if (permissions?.hasRole('dij') ?? false)
            ListTile(
              onTap: () => Modular.to.navigate('/home/dij'),
              selected: currentRoute.startsWith('/home/dij'),
              leading: const Icon(Icons.book_outlined),
              title: const Text('Página DIJ'),
            ),

          const Divider(),
          ListTile(
            onTap: () async {
              await authService.signOut();
              if (context.mounted) Modular.to.navigate('/');
            },
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}