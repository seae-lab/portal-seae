// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_modular/flutter_modular.dart';
// NOVO: Import necessário para a inicialização do idioma
import 'package:intl/date_symbol_data_local.dart';
import 'app_module.dart';
import 'app_widget.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- ESTA É A LINHA QUE FALTAVA ---
  // Ela carrega os dados de formatação para o português do Brasil.
  await initializeDateFormatting('pt_BR', null);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(ModularApp(module: AppModule(), child: const AppWidget()));
}