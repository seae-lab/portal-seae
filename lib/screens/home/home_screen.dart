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
          appBar: isDesktop
              ? null
              : AppBar(
            title: const Text('Painel Admin'),
          ),
          drawer: isDesktop ? null : const SideMenuWidget(),
          body: Row(
            children: [
              if (isDesktop) const SideMenuWidget(),
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