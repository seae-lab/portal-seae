// lib/widgets/login_form.dart

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
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

    final authService = Modular.get<AuthService>();
    final result = await authService.signInWithGoogle();

    if (mounted) {
      if (result != null) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
      } else {
        final initialRoute = authService.getInitialRouteForUser();
        // Correção final: limpa a pilha de navegação para não poder voltar ao login
        Modular.to.pushNamedAndRemoveUntil(initialRoute, (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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