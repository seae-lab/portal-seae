import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final authService = Modular.get<AuthService>();
    // Aguarda a verificação inicial de autenticação do serviço.
    await authService.initialAuthCheck;

    // Se o usuário estiver autenticado...
    if (authService.isAuthenticated) {
      // Pega a rota que o usuário tentou acessar (a URL do navegador)
      final initialRoute = Modular.initialRoute;

      // Se a rota inicial for a raiz, login, ou a própria splash,
      // navega para a rota padrão do usuário.
      if (initialRoute == '/' || initialRoute == '/login' || initialRoute.isEmpty) {
        Modular.to.navigate(authService.getInitialRouteForUser());
      } else {
        // Caso contrário, navega para a rota em que o usuário estava (deep link).
        Modular.to.navigate(initialRoute);
      }
    } else {
      // Se não estiver autenticado, vai para a tela de login.
      Modular.to.navigate('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}