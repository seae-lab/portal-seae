// lib/main.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app_module.dart';
import 'app_widget.dart';
import 'firebase_options.dart';

// Importação condicional!
import 'src/sw_registrar.dart'
if (dart.library.html) 'src/sw_registrar_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Apenas no build para web com JavaScript, definimos a persistência.
  // O Wasm ainda não suporta isso diretamente.
  if (const bool.fromEnvironment("dart.library.html")) {
    await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
  }

  runApp(ModularApp(module: AppModule(), child: const AppWidget()));

  // Esta chamada agora usa a versão correta do arquivo (vazia para wasm).
  registerServiceWorker();
}