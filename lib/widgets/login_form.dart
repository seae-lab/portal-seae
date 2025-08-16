import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart'; // 1. Import do Modular
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    // 2. Usando Modular.get() em vez de Provider.of() - ISTO CORRIGE O CRASH
    final authService = Modular.get<AuthService>();
    final result = await authService.signInWithGoogle();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result != null) {
        // Se o resultado não for nulo, houve um erro. Apenas mostramos a mensagem.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        // Se o resultado for nulo, o login foi um sucesso.
        // Navegamos explicitamente para a home.
        Modular.to.navigate('/home/overview');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Usando sua logo em PNG, que sabemos que funciona.
        Image.asset(
          'assets/images/logo_SEAE_azul.png',
          height: 80,
        ),
        const SizedBox(height: 16),
        Text(
          'Painel do Administrador',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 48),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
        // Um botão único e simples para todas as plataformas.
          ElevatedButton.icon(
            icon: SvgPicture.asset(
              'assets/images/google_logo.svg',
              height: 20.0,
            ),
            label: const Text(
              'Entrar com Google',
              style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
            ),
            onPressed: _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
      ],
    );
  }
}
