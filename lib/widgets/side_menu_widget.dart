import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/auth_service.dart';

class SideMenuWidget extends StatefulWidget {
  const SideMenuWidget({super.key});

  @override
  State<SideMenuWidget> createState() => _SideMenuWidgetState();
}

class _SideMenuWidgetState extends State<SideMenuWidget> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final authService = Modular.get<AuthService>();
    final permissions = authService.currentUserPermissions;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: _isCollapsed ? 80 : 250,
      color: Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            child: _isCollapsed
                ? Image.asset('assets/icons/logo_SEAE_icon.png')
                : Image.asset('assets/images/logo_SEAE_azul.png'),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Modular.routerDelegate,
              builder: (context, child) {
                final currentRoute = Modular.routerDelegate.path;
                final secretariaRoutes = [
                  '/home/dashboard',
                  '/home/gestao_membros',
                  '/home/relatorios_membros'
                ];

                return ListView(
                  children: [
                    if (permissions?.hasRole('secretaria') ?? false)
                      _buildDepartmentMenu(
                        context: context,
                        title: 'Secretaria',
                        icon: Icons.business_outlined,
                        isCollapsed: _isCollapsed,
                        mainPageRoute: '/home/dashboard',
                        subItems: [
                          if (permissions?.hasRole('secretaria_dashboard') ?? false)
                            _buildSubMenuItem(
                              title: 'Dashboard',
                              route: '/home/dashboard',
                              isSelected: currentRoute.startsWith('/home/dashboard'),
                            ),
                          if (permissions?.hasRole('secretaria_membros') ?? false)
                            _buildSubMenuItem(
                              title: 'Gestão de Membros',
                              route: '/home/gestao_membros',
                              isSelected: currentRoute.startsWith('/home/gestao_membros'),
                            ),
                          if (permissions?.hasRole('secretaria_relatorios') ?? false)
                            _buildSubMenuItem(
                              title: 'Relatórios',
                              route: '/home/relatorios_membros',
                              isSelected: currentRoute.startsWith('/home/relatorios_membros'),
                            ),
                        ],
                        isExpanded: secretariaRoutes.any((route) => currentRoute.startsWith(route)),
                      ),

                    if (permissions?.hasRole('dij') ?? false)
                      _buildSimpleMenuItem(
                        title: 'DIJ',
                        icon: Icons.book_outlined,
                        isCollapsed: _isCollapsed,
                        route: '/home/dij',
                        isSelected: currentRoute.startsWith('/home/dij'),
                      ),
                  ],
                );
              },
            ),
          ),
          const Divider(),
          _buildSimpleMenuItem(
            title: 'Sair',
            icon: Icons.logout,
            isCollapsed: _isCollapsed,
            onTap: () async {
              await authService.signOut();
              if (context.mounted) Modular.to.navigate('/');
            },
          ),
          IconButton(
            icon: Icon(
                _isCollapsed ? Icons.arrow_forward_ios : Icons.arrow_back_ios),
            onPressed: () {
              setState(() {
                _isCollapsed = !_isCollapsed;
              });
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDepartmentMenu({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isCollapsed,
    required String mainPageRoute,
    required List<Widget> subItems,
    required bool isExpanded,
  }) {
    if (isCollapsed) {
      // CORREÇÃO: Quando retrátil, usamos um SizedBox com IconButton.
      // O IconButton centraliza seu ícone por padrão.
      return SizedBox(
        height: 56, // Altura padrão para um item de menu
        child: IconButton(
          icon: Icon(icon, color: Theme.of(context).textTheme.bodyLarge?.color),
          tooltip: title, // Dica que aparece ao passar o mouse
          onPressed: () => Modular.to.navigate(mainPageRoute),
        ),
      );
    }

    return ExpansionTile(
      leading: Icon(icon),
      title: Text(title),
      initiallyExpanded: isExpanded,
      children: subItems,
    );
  }

  // MÉTODO ATUALIZADO
  Widget _buildSimpleMenuItem({
    required String title,
    required IconData icon,
    required bool isCollapsed,
    String? route,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    if (isCollapsed) {
      // CORREÇÃO: Mesma lógica aplicada aqui para consistência.
      return SizedBox(
        height: 56,
        child: IconButton(
          icon: Icon(icon, color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyLarge?.color),
          tooltip: title,
          onPressed: onTap ?? () => Modular.to.navigate(route!),
        ),
      );
    }

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: isSelected,
      onTap: onTap ?? () => Modular.to.navigate(route!),
    );
  }

  Widget _buildSubMenuItem({
    required String title,
    required String route,
    required bool isSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 30.0),
      child: ListTile(
        title: Text(title),
        selected: isSelected,
        onTap: () => Modular.to.navigate(route),
        dense: true,
      ),
    );
  }
}