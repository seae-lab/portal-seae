import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/auth_service.dart';

class SideMenuWidget extends StatelessWidget {
  const SideMenuWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Pega o caminho atual para saber qual item do menu destacar
    final currentRoute = Modular.routerDelegate.path;

    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            child: Image.asset('assets/images/logo_SEAE_azul.png'),
          ),
          ListTile(
            onTap: () => Modular.to.navigate('/home/overview'),
            selected: currentRoute.startsWith('/home/overview'),
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Visão Geral'),
          ),
          ListTile(
            onTap: () => Modular.to.navigate('/home/users'),
            selected: currentRoute.startsWith('/home/users'),
            leading: const Icon(Icons.people_alt_outlined),
            title: const Text('Usuários'),
          ),
          const Divider(),
          ListTile(
            onTap: () {
              Modular.get<AuthService>().signOut();
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