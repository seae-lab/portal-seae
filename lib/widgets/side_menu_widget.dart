import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/auth_service.dart';

class SideMenuWidget extends StatefulWidget {
  final bool isDesktop;
  const SideMenuWidget({super.key, required this.isDesktop});

  @override
  State<SideMenuWidget> createState() => _SideMenuWidgetState();
}

class _SideMenuWidgetState extends State<SideMenuWidget> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final authService = Modular.get<AuthService>();
    final permissions = authService.currentUserPermissions;

    final canAccessDijGeral = permissions?.hasRole('dij') ?? false;
    final canAccessGestaoJovens = (permissions?.hasRole('dij_diretora') ?? false) || (permissions?.hasRole('dij') ?? false) || (permissions?.hasRole('dij_ciclo_1') ?? false) || (permissions?.hasRole('dij_ciclo_2') ?? false) || (permissions?.hasRole('dij_ciclo_3') ?? false) || (permissions?.hasRole('dij_pos_juventude') ?? false);
    final canAccessChamada = (permissions?.hasRole('dij_diretora') ?? false) || (permissions?.hasRole('dij') ?? false) || (permissions?.hasRole('dij_ciclo_1') ?? false) || (permissions?.hasRole('dij_ciclo_2') ?? false) || (permissions?.hasRole('dij_ciclo_3') ?? false) || (permissions?.hasRole('dij_pos_juventude') ?? false);
    final canAccessSecretaria = permissions?.hasRole('secretaria') ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: _isCollapsed && widget.isDesktop ? 80 : 250,
      color: Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            child: _isCollapsed && widget.isDesktop
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
                  '/home/gestao_bases',
                  '/home/relatorios_membros'
                ];
                final dijRoutes = [
                  '/home/dij',
                  '/home/dij/calendario',
                  '/home/dij/jovens',
                  '/home/dij/chamada'
                ];

                return ListView(
                  children: [
                    if (canAccessSecretaria)
                      _buildDepartmentMenu(
                        context: context,
                        title: 'Secretaria',
                        icon: Icons.business_outlined,
                        isCollapsed: _isCollapsed && widget.isDesktop,
                        mainPageRoute: '/home/dashboard',
                        subItems: [
                          if (permissions?.hasRole('secretaria') ?? permissions?.hasRole('secretaria_dashboard') ?? false)
                            _buildSubMenuItem(
                              title: 'Dashboard',
                              route: '/home/dashboard',
                              isSelected: currentRoute.startsWith('/home/dashboard'),
                            ),
                          if (permissions?.hasRole('secretaria') ?? permissions?.hasRole('secretaria_membros') ?? false)
                            _buildSubMenuItem(
                              title: 'Gestão de Membros',
                              route: '/home/gestao_membros',
                              isSelected: currentRoute.startsWith('/home/gestao_membros'),
                            ),
                          if (permissions?.hasRole('admin') ?? false)
                            _buildSubMenuItem(
                              title: 'Gestão de Bases',
                              route: '/home/gestao_bases',
                              isSelected: currentRoute.startsWith('/home/gestao_bases'),
                            ),
                          if (permissions?.hasRole('secretaria') ?? permissions?.hasRole('secretaria_relatorios') ?? false)
                            _buildSubMenuItem(
                              title: 'Relatórios',
                              route: '/home/relatorios_membros',
                              isSelected: currentRoute.startsWith('/home/relatorios_membros'),
                            ),
                        ],
                        isExpanded: secretariaRoutes.any((route) => currentRoute.startsWith(route)),
                      ),

                    if (canAccessDijGeral || canAccessGestaoJovens || canAccessChamada)
                      _buildDepartmentMenu(
                        context: context,
                        title: 'DIJ',
                        icon: Icons.school_outlined,
                        isCollapsed: _isCollapsed && widget.isDesktop,
                        mainPageRoute: '/home/dij',
                        subItems: [
                          _buildSubMenuItem(
                            title: 'Página Principal',
                            route: '/home/dij',
                            isSelected: currentRoute == '/home/dij',
                          ),
                          if (canAccessGestaoJovens)
                            _buildSubMenuItem(
                              title: 'Cadastro de Jovens',
                              route: '/home/dij/jovens',
                              isSelected: currentRoute.startsWith('/home/dij/jovens'),
                            ),
                          if (canAccessChamada)
                            _buildSubMenuItem(
                              title: 'Chamada',
                              route: '/home/dij/chamada',
                              isSelected: currentRoute.startsWith('/home/dij/chamada'),
                            ),
                          _buildSubMenuItem(
                            title: 'Calendário de Encontros',
                            route: '/home/dij/calendario',
                            isSelected: currentRoute.startsWith('/home/dij/calendario'),
                          ),
                        ],
                        isExpanded: dijRoutes.any((route) => currentRoute.startsWith(route)),
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
            isCollapsed: _isCollapsed && widget.isDesktop,
            onTap: () async {
              await authService.signOut();
              if (context.mounted) Modular.to.navigate('/');
            },
          ),
          if (widget.isDesktop)
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
      return SizedBox(
        height: 56,
        child: IconButton(
          icon: Icon(icon, color: Theme.of(context).textTheme.bodyLarge?.color),
          tooltip: title,
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

  Widget _buildSimpleMenuItem({
    required String title,
    required IconData icon,
    required bool isCollapsed,
    String? route,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    final action = onTap ?? () {
      Modular.to.navigate(route!);
      if (!widget.isDesktop) {
        Navigator.of(context).pop();
      }
    };

    if (isCollapsed) {
      return SizedBox(
        height: 56,
        child: IconButton(
          icon: Icon(icon, color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyLarge?.color),
          tooltip: title,
          onPressed: action,
        ),
      );
    }

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: isSelected,
      onTap: action,
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
        onTap: () {
          Modular.to.navigate(route);
          if (!widget.isDesktop) {
            Navigator.of(context).pop();
          }
        },
        dense: true,
      ),
    );
  }
}