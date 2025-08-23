import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/auth_service.dart';
import 'package:projetos/widgets/side_menu_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _inactivityTimer;
  final Duration _maxInactivity = const Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _startInactivityTimer();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_maxInactivity, _logOutUser);
  }

  void _resetInactivityTimer() {
    _startInactivityTimer();
  }

  void _logOutUser() {
    final authService = Modular.get<AuthService>();
    if (authService.isAuthenticated && mounted) {
      authService.signOut();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sua sessão expirou por inatividade.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listener para detectar qualquer interação do usuário e resetar o timer
    return Listener(
      onPointerDown: (_) => _resetInactivityTimer(),
      onPointerMove: (_) => _resetInactivityTimer(),
      onPointerUp: (_) => _resetInactivityTimer(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 700;

          return Scaffold(
            appBar: isDesktop
                ? null
                : AppBar(
              title: const Text('Painel Admin'),
            ),
            drawer: isDesktop ? null : const SideMenuWidget(isDesktop: false),
            body: Row(
              children: [
                if (isDesktop) const SideMenuWidget(isDesktop: true),
                const Expanded(
                  child: RouterOutlet(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}