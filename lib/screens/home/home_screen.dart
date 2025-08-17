import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/screens/home/widgets/side_menu_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print("--- RECONSTRUINDO HomeScreen ---");
    return LayoutBuilder(
      builder: (context, constraints) {
        // Verifica se a tela é larga o suficiente para o menu lateral fixo
        final isDesktop = constraints.maxWidth > 700;

        return Scaffold(
          // No desktop, não precisamos do AppBar, pois o menu é fixo
          appBar: isDesktop
              ? null
              : AppBar(
            title: const Text('Painel Admin'),
          ),
          // No mobile, o menu vira uma "gaveta" (drawer)
          drawer: isDesktop ? null : const SideMenuWidget(),
          body: Row(
            children: [
              // Se for desktop, mostra o menu lateral fixo
              if (isDesktop) const SideMenuWidget(),
              // O RouterOutlet é a área onde as páginas filhas serão renderizadas
              const Expanded(
                child: RouterOutlet(),
              ),
            ],
          ),
        );
      },
    );
  }
}