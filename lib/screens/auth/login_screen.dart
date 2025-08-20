import 'package:flutter/material.dart';
import '../../widgets/login_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24.0),
            child: isMobile
                ? const LoginForm() // Layout para mobile
                : Center(      // Layout para web/desktop
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Card(
                  color: Colors.white,
                  elevation: 8.0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
                    child: LoginForm(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
