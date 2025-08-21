import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/widgets/side_menu_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
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
    );
  }
}